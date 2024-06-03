import { createStore } from 'vuex'
import detectEthereumProvider from "@metamask/detect-provider";
import { localhost } from "viem/chains";
import {
  createWalletClient,
  custom,
  createPublicClient,
  decodeEventLog,
  toHex,
} from "viem";


const axios = require("axios");
const BigNumber = require("bignumber.js");
export default createStore({
  state: {
    currentLevel: 10,
    address: "0x388C818CA8B9251b393131C08a736A67ccB19297",
    basePoints: 10,
    paused: false,
    player: {},
    currentLevelTime: 120,
    sizePenalty: 5,
    total: 0,
    incrementCollected: 0,
    speed: 10,
    pausedSpeed: 30,
    score: 0,
    showLeaderBoard: false,
    winnings: [1, 2, 3, 4, 4, 5, 6, 7, 11, 1, 12, 12, 1],
    isLoading: false,
    connected: false

  },
  getters: {
  },
  mutations: {
  },
  actions: {
    async getWinnings(_context, _data) {

    },
    async claimWinnings(_context, _data) {

    },
    connectWallet: async function (_context, _data) {
      try {
        if (this.state.connected) {
          this.state.connected = false;
          this.state.account = "";
          return;
        }
        const provider = await detectEthereumProvider();
        if (!provider) return;
        this.state.isLoading = true;
        await this.dispatch("initContracts");
        this.dispatch("setupListeners");
        this.state.publicClient = createPublicClient({
          batch: {
            multicall: true,
          },
          chain: localhost,
          transport: custom(window.ethereum),
        });

        this.state.walletClient = createWalletClient({
          chain: localhost,
          transport: custom(window.ethereum),
        });
        console.log(await this.state.walletClient.getAddresses());
        const [accountsGet, accountsRequest] = await Promise.all([
          this.state.walletClient.getAddresses(),
          this.state.walletClient.requestAddresses(),
        ]);
        const accounts = accountsGet.length > 0 ? accountsGet : accountsRequest;
        if (accounts.length === 0) {
          this.state.isLoading = false;
          return;
        }
        this.state.account = accounts[0];
        this.state.connected = true;
        console.log("accounts: ", this.state.account);
       
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
          params: [{ chainId: process.env.VUE_APP_CHAINID }],
        });
      } catch (switchError) {
        if (switchError.code === 4902) {
          // You can make a request to add the chain to wallet here
          console.log("Sepolia Testnet hasnt been added to the wallet!");
          await this.dispatch("addNetwork");
        }
      }
    },
    setupListeners: async function (_context, _data) {
      const chainId = await window.ethereum.request({ method: "eth_chainId" });
      console.log("chainId: ", chainId);
      if (chainId != process.env.VUE_APP_CHAINID) {
        await this.dispatch("switchToSepolia");
      }
      window.ethereum.on("chainChanged", async (_chainId) => {
        window.location.reload();
      });
      window.ethereum.on("accountsChanged", async (accounts) => {
        console.log("accounts: ", accounts);
        window.location.reload();
      });
    },
    async addNetwork() {
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: "0x89",
              rpcUrls: [process.env.VUE_RPC_URL],
              chainName: process.env.VUE_RPC_NAME,
              nativeCurrency: {
                name: process.env.VUE_RPC_CURRENCY,
                symbol: process.env.VUE_RPC_SYMBOL,
                decimals: process.env.VUE_RPC_DECIMALS,
              },
              blockExplorerUrls: ["https://polygonscan.com/"],
            },
          ],
        });
      } catch (error) {
        console.error("error adding chain", error);
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
        /* Read more about isConfirmed, isDenied below */
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
        footer: `<a href=https://sepolia.etherscan.io//txs/${message.txHash}> View on Sepolia scan</a>`,
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
