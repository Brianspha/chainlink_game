import { createStore } from 'vuex'
import detectEthereumProvider from "@metamask/detect-provider";
import { localhost, sepolia } from "viem/chains";
import {
  createWalletClient,
  custom,
  createPublicClient,
  toHex, http,
  decodeEventLog,
  encodePacked,
  keccak256,
  decodeErrorResult
} from "viem";
import { privateKeyToAccount } from 'viem/accounts'
import * as addresses from "../../../contracts/deploy-out/deploymentSepolia.json";
import * as GAMEABI from "../../../contracts/out/Game.sol/Game.json";
import * as TOKENABI from "../../../contracts/out/Token.sol/Token.json";
import * as NFTABI from "../../../contracts/out/NFT.sol/NFT.json";
import * as BigN from "bignumber.js";
import swal from "sweetalert2";

const account = privateKeyToAccount(import.meta.env.VITE_PRIVATE_KEY)

const GAME_ABI = GAMEABI.abi
const TOKEN_ABI = TOKENABI.abi
const NFT_ABI = NFTABI.abi
const BigNumber = BigN.BigNumber;
export default createStore({
  state: {
    currentLevel: 10,
    address: "",
    basePoints: 10,
    paused: false,
    player: {},
    currentLevelTime: 400,
    sizePenalty: 5,
    total: 0,
    incrementCollected: 0,
    speed: 10,
    pausedSpeed: 30,
    score: 0,
    showLeaderBoard: false,
    winnings: [],
    isLoading: false,
    connected: false,
    publicClient: {},
    walletClient: {},
    paymentTokenDetails: {},
    canPlay: false,
    leaderBoard: [],
    chainId: 0,
    prizePool: []

  },
  getters: {
  },
  mutations: {
  },
  actions: {
    async getWinnings(_context, _data) {
      if (!this.state.connected) return;
      try {
        this.state.isLoading = true
        const encodedPacked = keccak256(encodePacked(
          ['address', 'uint256'],
          [this.state.address, this.state.chainId]
        ))
        const signature
          = await account.signMessage({
            message: { raw: encodedPacked },
          })

        const { result } = await this.state.publicClient.simulateContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "getWinnings",
          args: [
            this.state.incrementCollected,
            signature
          ],
        });
        this.state.winnings = Array.from(result);
        this.state.isLoading = false
        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error getWinnings", error)
        return false
      }
    },
    async getLeaderBoard(_context, _data) {
      if (!this.state.connected) {
        return;
      }
      try {
        this.state.isLoading = true
        const scores = await this.dispatch("getLatestScores")
        if (scores.length > 0) {
          const updatedData = await this.dispatch("sortScoresAndAddresses", [
            scores[0], scores[1]
          ])
          const updatedScores = updatedData[0]
          const updatedAddresses = updatedData[1]
          const leaderboard = updatedScores.map((score, index) => {

            return {
              name: `https://sepolia.etherscan.io/address/${updatedAddresses[index]}`,
              namesub: `${updatedAddresses[index].substring(0, 3)}...${updatedAddresses[index].substring(updatedAddresses[index].length - 3, updatedAddresses[index].length)}`,
              score: score,
              rank: index + 1,
              chain: this.state.chainId
            }
          })
          this.state.leaderBoard = leaderboard
          this.state.isLoading = false
        }
      } catch (error) {
        console.error("Unable to load leaderboard: ", error)
      }
    },
    async getLatestScores(_context, _data) {
      if (!this.state.connected) return

      try {
        const latestScores = await this.state.publicClient.readContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "scores",
          args: [
          ],
        })
        return latestScores
      } catch (error) {
        console.error("error getting latest scores: ", error)
        return []
      }
    },
    async claimWinnings(_context, _data) {
      if (!this.state.connected) return;
      if (this.state.winnings.length === 0) {
        this.dispatch("error", "Not eligble for any winnings")
        return
      }
      try {
        this.state.isLoading = true
        const latestScores = await this.dispatch("getLatestScores")

        if (latestScores.length === 0) {
          this.dispatch("error", "Something went wrong")
          return
        }

        let userscores = latestScores[0]
        let latestAddresses = latestScores[1]
        latestAddresses.push(this.state.address)
        userscores.push(this.state.score)
        const updatedData = await this.dispatch("sortScoresAndAddresses", [
          userscores, latestAddresses
        ])
        userscores = updatedData[0]
        latestAddresses = updatedData[1]
        const encodedPacked = keccak256(encodePacked(
          ['uint256[]', 'address', 'uint256'],
          [userscores, this.state.address, this.state.chainId]
        ))
        const signature
          = await account.signMessage({
            message: { raw: encodedPacked },
          })
        this.state.isLoading = true
        const hash = await this.state.walletClient.writeContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "submitScore",
          args: [
            userscores,
            latestAddresses,
            signature,
            this.state.winnings
          ],
        });
        const txReceipt = await this.state.publicClient.waitForTransactionReceipt({
          hash: hash,
        });
        if (txReceipt.status !== "reverted") {
          this.dispatch("success", "Successfully claimed winnings please check your wallet for latest balances")
        }
        else {
          this.dispatch("error", "Something went wrong while submitting scores")
        }
        this.state.isLoading = false
        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error getWinnings", error)

        return false
      }
    },
    async sortScoresAndAddresses(_context, data) {
      let userscores, latestAddresses;
      [userscores, latestAddresses] = data;


      let combined = userscores.map((score, index) => {
        return { score: new BigNumber(score), address: latestAddresses[index] };
      });

      combined.sort((a, b) => b.score.comparedTo(a.score));

      let sortedScores = combined.map(item => item.score.toString());
      let sortedAddresses = combined.map(item => item.address);

      return [
        sortedScores, sortedAddresses
      ];
    },
    async freePlay(_context, _data) {
      if (!this.state.connected) return;

      try {
        this.state.isLoading = true
        let alreadyClaimed = await this.state.publicClient.readContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "freePlays",
          args: [
            this.state.address
          ],
        })
        if (alreadyClaimed) {
          this.dispatch("error", "Already claimed free play");
          return
        }
        const hash = await this.state.walletClient.writeContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "freePlay",
          args: [
          ],
        });
        await this.state.publicClient.waitForTransactionReceipt({
          hash: hash,
        });
        alreadyClaimed = await this.state.publicClient.readContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "freePlay",
          args: [
            this.state.address
          ],
        })
        if (alreadyClaimed) {
          this.dispatch("success", "Successfully claimed free play token");
          this.state.canPlay = true
        }

        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error freePlay", error)
        return false
      }
    },
    async paidPlay(_context, _data) {
      if (!this.state.connected) return;
      try {
        await this.dispatch("checkPaymentTokenApproval")

        this.state.isLoading = true
        const hash = await this.state.walletClient.writeContract({
          abi: GAME_ABI,
          account: this.state.address,
          address: addresses.Game,
          functionName: "play",
          args: [
          ],
        });
        await this.state.publicClient.waitForTransactionReceipt({
          hash: hash,
        });
        this.dispatch("success", "Game starting");
        this.state.canPlay = true
        return true
      } catch (error) {
        this.state.isLoading = false
        console.error("error paidPlay", error)
        return false
      }
    },
    getPaymentTokenDetails: async function (_context, _data) {
      if (!this.state.connected) return;
      try {
        this.state.isLoading = true;
        let tokenDetails = await Promise.all([
          this.state.publicClient.readContract({
            abi: TOKEN_ABI,
            address: addresses.Token,
            functionName: "name",
          }),
          this.state.publicClient.readContract({
            abi: TOKEN_ABI,
            address: addresses.Token,
            functionName: "symbol",
          }),
          this.state.publicClient.readContract({
            abi: TOKEN_ABI,
            address: addresses.Token,
            functionName: "decimals",
          }),
        ]);
        this.state.paymentTokenDetails = {
          name: tokenDetails[0],
          symbol: tokenDetails[1],
          decimals: tokenDetails[2],
          address: addresses.PaymentToken,
        };
        this.state.isLoading = false;
      } catch (error) {
        console.error("Unable to load Payment Token Details: ", error);
        this.state.isLoading = false;
        this.dispatch("error", "Unable to load Payment Token Details");
      }
    },
    async checkPaymentTokenApproval(_context, _data) {
      this.state.isLoading = true;
      const approved = await this.state.publicClient.readContract({
        abi: TOKEN_ABI,
        account: this.state.address,
        address: addresses.Token,
        functionName: "allowance",
        args: [this.state.address, addresses.Game],
      });
      if (approved == 0) {
        const hash = await this.state.walletClient.writeContract({
          abi: TOKEN_ABI,
          account: this.state.address,
          address: addresses.Token,
          functionName: "approve",
          args: [
            addresses.Game,
            new BigNumber(Number.MAX_SAFE_INTEGER + 1)
              .multipliedBy(
                new BigNumber(10 ** this.state.paymentTokenDetails.decimals)
              )
              .toFixed(0),
          ],
        });
        await this.state.publicClient.waitForTransactionReceipt({
          hash: hash,
        });
        this.dispatch("success", "Successfully approved payment token");
        this.state.isLoading = false;
      }
      return approved == 0;
    },
    connectWallet: async function (_context, _data) {
      try {
        if (this.state.connected) {
          this.state.connected = false;
          this.state.address = "";
          return;
        }
        const provider = await detectEthereumProvider();
        if (!provider) return;
        this.state.isLoading = true
        this.state.publicClient = createPublicClient({
          batch: {
            multicall: true,
          },
          chain: sepolia,
          transport: custom(window.ethereum),
        });

        this.state.walletClient = createWalletClient({
          chain: sepolia,
          transport: custom(window.ethereum),
        });

        const [accountsGet, accountsRequest, ___] = await Promise.all([
          this.state.walletClient.getAddresses(),
          this.state.walletClient.requestAddresses()
        ]);
        const accounts = accountsGet.length > 0 ? accountsGet : accountsRequest;
        if (accounts.length === 0) {
          this.state.isLoading = false;
          return;
        }
        this.state.address = accounts[0];
        this.state.connected = true;
        const [chainId, prizePool, _,] = await Promise.all([
          this.state.publicClient.getChainId(),
          this.state.publicClient.readContract({
            abi: GAME_ABI,
            account: this.state.address,
            address: addresses.Game,
            functionName: "getPrizePool",
            args: [
            ],
          }),
          this.dispatch("getPaymentTokenDetails"),
        ])

        this.state.prizePool = prizePool
        this.state.chainId = chainId
        await Promise.all([
          this.dispatch("setupListeners"),
          this.dispatch("addPlayTokenToWallet")
        ])
        this.state.isLoading = false;
      } catch (error) {
        console.error(error);
        this.state.isLoading = false;
      }
    },
    success(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "success",
        title: "Success",
        showConfirmButton: false,
        timer: 2500,
        text: message,
      });
    },
    async switchToSepolia() {
      try {
        await ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: import.meta.env.VITE_APP_CHAINID }],
        });
      } catch (switchError) {
        if (switchError.code === 4902) {
          console.log("Sepolia Testnet hasn't been added to the wallet!");
          await this.dispatch("addNetwork");
        }
      }
    },
    setupListeners: async function (_context, _data) {
      const chainId = await window.ethereum.request({ method: "eth_chainId" });
      if (chainId != import.meta.env.VITE_APP_CHAINID) {
        await this.dispatch("switchToSepolia");
      }
      window.ethereum.on("chainChanged", async (_chainId) => {
        window.location.reload();
      });
      window.ethereum.on("accountsChanged", async (accounts) => {
        window.location.reload();
      });
    },
    async addNetwork() {
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: import.meta.env.VITE_APP_CHAINID,
              rpcUrls: [import.meta.env.VITE_RPC_URL],
              chainName: import.meta.env.VITE_RPC_NAME,
              nativeCurrency: {
                name: import.meta.env.VITE_RPC_CURRENCY,
                symbol: import.meta.env.VITE_RPC_SYMBOL,
                decimals: import.meta.env.VITE_RPC_DECIMALS,
              },
              blockExplorerUrls: ["https://sepolia.etherscan.io/"],
            },
          ],
        });
      } catch (error) {
        console.error("error adding chain", error);
      }
    },
    async addPlayTokenToWallet(_context, _data) {

      try {
        // wasAdded is a boolean. Like any RPC method, an error may be thrown.
        const wasAdded = await window.ethereum.request({
          method: 'wallet_watchAsset',
          params: {
            type: 'ERC20', // Initially only supports ERC20, but eventually more!
            options: {
              address: addresses.Token, // The address that the token is at.
              symbol: this.state.paymentTokenDetails.symbol, // A ticker symbol or shorthand, up to 5 chars.
              decimals: this.state.paymentTokenDetails.decimals, // The number of decimals in the token
              image: "https://cdn3.iconfinder.com/data/icons/meteocons/512/n-a-512.png", // A string url of the token logo
            },
          },
        });

        if (wasAdded) {
          this.dispatch("success", "Play token was added successfully")
        } else {
          this.dispatch("warning", "To play the game and track rewards please add the play toke manually")
        }
      } catch (error) {
        console.log(error);
      }
    },
    successWithCallBack(_context, message) {
      swal
        .fire({
          position: "top-end",
          icon: "success",
          title: "Success",
          showConfirmButton: true,
          text: message.message,
        })
        .then((results) => {
          if (results.isConfirmed) {
            message.onTap();
          }
        });
    },
    warning(_context, message) {
      swal.fire("Warning", message.warning, "warning").then((result) => {
        if (result.isConfirmed) {
          message.onTap();
        }
      });
    },
    toastError(_context, message) {
      toast.error(message);
    },
    toastWarning(_context, message) {
      toast.warning(message);
    },
    toastSuccess(_context, message) {
      toast.success(message);
    },
    error(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "error",
        title: "Error!",
        showConfirmButton: false,
        timer: 2500,
        text: message,
      });
    },
    successWithFooter(_context, message) {
      swal.fire({
        position: "top-end",
        icon: "success",
        title: "Success",
        text: message.message,
        footer: `<a href=https://sepolia.etherscan.io/txs/${message.txHash}> View on Sepolia scan</a>`,
      });
    },
    errorWithFooterMetamask(_context, message) {
      swal.fire({
        icon: "error",
        title: "Error!",
        text: message,
        footer: `<a href= https://metamask.io> Download Metamask</a>`,
      });
    },
  },
  modules: {
  }
})
