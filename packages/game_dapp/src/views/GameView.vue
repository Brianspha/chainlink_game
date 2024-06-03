<template>
    <div id="zim" />
    <LeaderboardDialog />
</template>

<script setup lang="js">
import { ref, onMounted, onBeforeUnmount, computed } from 'vue';
import { useStore } from 'vuex';
import { LeaderBoard, Board, Scorer, Timer, Dialog } from '@zimjs/game';
import LeaderboardDialog from "../components/LeaderboardDialog.vue"

import {
    timeout,
    Flipper,
    Tabs,
    shuffle, Bitmap, Pane, Ticker, Button, Boundary, MotionController, Emitter, Shape, Frame,
    Circle, Tile, Container, Rectangle, rand, Blob, Label, series
} from 'zimjs';

let frame = ref(null);
const store = useStore();
const colors = ['yellow', 'orange', 'black', 'red', 'green', 'purple'];
const currentLevel = computed(() => store.state.currentLevel);
const sizePenalty = computed(() => store.state.sizePenalty);
const currentLevelTime = computed(() => store.state.currentLevelTime);
const userAddress = computed(() => store.state.address);
const paused = computed(() => store.state.paused);
const basePoints = computed(() => store.state.basePoints);
const score = computed(() => store.state.score);
const winnings = computed(() => store.state.winnings);
console.log("winnings: ", store.state.time)
let speed = 0;
let winingCards = []
let snap = null;
let mapCheck = false;
let player;
let controller;
let world;
let stage;
let stageW;
let stageH;
let tile;
let map;
let emitter;
let pieces;
let stars;
let currentColor;
let tempPlayerParent;
let mapTile;
let mapPlayerScale;
let mapPlayer
let mapContainer;
let timer;
let scorer;
let menu;
let mainMenu;
let loadingAnimation;
let mainMenuOptions;
let leaderboard
let cardsContainer;
let winningsIndex;
function initGame() {
    console.log('ready from ZIM Frame'); // logs in console (F12 - choose console)
    stageW = frame.value.width;
    stageH = frame.value.height;
    stage = frame.value.stage;

    tile = new Tile({
        obj: new Circle({ min: 50, max: 30 }, colors),
        cols: currentLevel.value,
        rows: currentLevel.value,
        spacingH: 500,
        spacingV: 500,
    }).animate({
        props: { scale: 2 },
        rewind: true,
        loop: true,
        ease: 'elasticOut',
        sequence: 0,
    });

    world = new Container(tile.width, tile.height).center();
    tile.centerReg(world);
    const edges = new Rectangle(tile.width + 400, tile.height + 400, clear, black, 2, 50, true).alp(.8)
        .center(world);
    mapTile = tile.clone()

    currentColor = setPlayerColor(colors);
    player = new Blob({
        color: currentColor,
        borderColor: 'black',
        borderWidth: 5,
        interactive: false,
        width: 50,
        height: 50,

    })
        .transformPoints("scale", .8)
        .transformPoints("rotation", 90)
        .centerReg(world)
    changeColor()
    new Label({
        text: getUsername(userAddress.value),
        size: 40,
        color: 'white',
    }).centerReg(player);

    frame.value.follow(player);
    const colorSeries = series(colors);


    stars = new Emitter({
        obj: makeStar,
        random: { rotation: { min: 0, max: 360 } },
        num: 1,
        life: 1000,
        decayTime: 1000,
        animation: {
            props: { rotation: [-360, 360] },
            ease: 'linear',
            loop: true,
        },
        startPaused: true,
    });

    pieces = new Emitter({
        obj: new Rectangle(40, 40, colors),
        random: { rotation: { min: 0, max: 360 } },
        num: 3,
        life: 1000,
        decayTime: 1000,
        animation: {
            props: { rotation: [-360, 360] },
            ease: 'linear',
            loop: true,
        },
        startPaused: true,
    });

    controller = new MotionController({
        target: player,
        type: 'keydown',
        container: world,
        rotate: true,
        speed: store.state.speed,
        boundary: new Boundary(0, 0, tile.width, tile.height),
    });



    const mapButton = new Button({
        label: "Map",
        backgroundColor: 'black',
        rollBackgroundColor: 'green',
        corner: 5,
        width: 150,
    }).sca(0.8).pos(30, 30, "BOTTOM");

    timer = new Timer({
        time: currentLevelTime.value,
        borderColor: 'dark',
    }).sca(0.8).pos(30, 110, 'BOTTOM');

    scorer = new Scorer({
        backgroundColor: yellow,
        score: store.state.score,
    }).sca(0.8).pos(30, 200, 'BOTTOM');
    menu = new Button({
        label: "Menu",
        backgroundColor: 'black',
        rollBackgroundColor: 'green',
        corner: 5,
        width: 150,
    }).sca(0.8).pos(30, 290, "BOTTOM").tap(function () {
        // createGame()
        showWinnings()
    });
    timer.on('complete', () => {
        timer.backing.color = 'red';
        timer.color = 'white';
        showWinnings()
        stage.update();
    });
    mapButton.on("mousedown", showMap);
    mapButton.on("pressup", hideMap);

    mapButton.addTo(stage);

    Ticker.add(update, stage);
}

function update() {
    if (paused.value) {
        return
    }
    currentColor = currentColor === null || player.color === undefined ? player.color : currentColor;

    if (timer.time <= 0) {
        showWinnings()
        pausePlayer();
    }

    tile.loop((dot, i) => {
        if (paused.value) {
            console.log("paaaasued: ", paused.value)
            return
        }
        if (paused.value) return;
        if (player.color === currentColor && player.hitTestCircle(dot) && dot.color === currentColor) {
            store.state.incrementCollected++;
            const comboMultiplier = store.state.incrementCollected > 1 ? store.state.incrementCollected : 1;
            const timeBonus = Math.floor(timer.time / 10);
            const difficultyMultiplier = currentLevel.value;
            const scoreIncrement = basePoints.value * comboMultiplier + timeBonus * difficultyMultiplier;
            scorer.score += scoreIncrement;
            store.state.score += scoreIncrement
            const timeIncrement = basePoints.value * 0.1;
            timer.time += timeIncrement;
            stars.loc(dot).spurt(5);
            dot.removeFrom();
            stage.update();
        } else if (player.color === currentColor && player.hitTestCircle(dot) && dot.color !== currentColor) {
            player.width -= sizePenalty.value;
            player.height -= sizePenalty.value;
            player.animate({
                props: { scale: 1.5 },
                rewind: true,
                loop: false,
                ease: 'elasticOut',
                sequence: 0,
                time: .1,
            })
            dot.removeFrom();
            stage.update();
        }
    }, true);
}

function setPlayerColor(colors) {
    let tempColor;
    do {
        tempColor = colors[Math.floor(rand(0, colors.length))];
    } while (tempColor === undefined);
    return tempColor;
}

function makeStar() {
    const star = new Shape(-20, -20, 40, 40);
    star.graphics.f(player.color).dp(0, 0, 18, 6, rand(0.5, 0.8));
    return star.sca(2);
}

function showMap() {
    if (mapCheck) return;
    mapCheck = true;
    pausePlayer();
    player.addTo(tile);
    tile.scaleTo(stage, 70, 70);
    snap = new Bitmap(world).center();
    console.log("tile before: ", tile)
    tile.sca(1);
    player.addTo(world);
    world.visible = false;
    stage.update();
}

function hideMap() {
    if (!mapCheck) return;
    mapCheck = false;
    continuePlay();
    world.visible = true;
    if (snap) snap.removeFrom();
    stage.update();
}

function continuePlay() {
    controller.speed = store.state.speed;
    store.state.paused = false;
    timer.start();
    stage.update();
}

function pausePlayer() {
    controller.speed = 0;
    store.state.paused = true;
    timer.stop();
    stage.update();
}

function changeColor() {
    setInterval(function () {
        if (!paused.value) {
            const randomIndex = Math.floor(Math.random() * colors.length);
            currentColor = colors[randomIndex];
            player.color = currentColor;
            stage.update();
        }

    }, 5000);
}
function getUsername(address) {
    let username = address && address.length > 0 ? address.substring(0, 3) + "...." + address.substring(address.length - 3, address.length) : ''
    return username
}
function hideMenu() {
    loadingAnimation.removeFrom()
    mainMenu.removeFrom()
}
function showMenu() {
    loadingAnimation.addTo()
    mainMenu.addTo()
}
function showLeaderBoard() {
    store.state.showLeaderBoard = true
}
function createGame() {
    if (frame.value) {
        frame.value.dispose();
    }
    frame.value = new Frame({
        scaling: 'fit', // Make sure this is set to fit or a similar option
        width: window.innerWidth,
        height: window.innerHeight,
        color: 'lighter',
        outerColor: 'grey',
        mouseMoveOutside: true, // so Pen and Dial work better
        ready: () => {
            loadingAnimation = new Container(window.innerWidth, window.innerHeight).addTo();
            new Blob({
                controlType: "none",
                points: 6,
                color: green,
                interactive: false,
            })
                .center(loadingAnimation)
                .sca(5, 3)
                .sha("rgba(0,0,0,.3)", 10, 15, 10);

            // LOGO
            // we make the logo intro relevant to the game
            // we pretend to place the logo on the shadow
            new Label("No Name Game", 130, "game", dark)
                .center(loadingAnimation).mov(10, 10)


            mainMenu = new Pane({
                label: "No Name Game",
                color: white,
                backing: loadingAnimation,
                displayClose: false,
                backdropClose: false,
            }).show();
            mainMenu.mov(0, -20)
            mainMenuOptions = new Tabs({
                width: 600,
                height: 60,
                tabs: ["Play", "Leaderboard", "About"],
                currentSelected: false,
                spacing: 30,
                backgroundColor: yellow,
                rollBackgroundColor: 'transparent',
                color: black,
                corner: 20
            }).center(mainMenu).mov(10, 120).tap(function () {
                switch (mainMenuOptions.text) {
                    case "Play":
                        hideMenu()
                        initGame()
                        break;
                    case "Leaderboard":
                        showLeaderBoard()
                        break;
                    case "About":
                        initGame()
                        break;
                    default:
                        initGame()
                        break;
                }
            })


        },
    });
}
function hideGame() {
    world.visible = false;
    stage.update();
}
function makeCard() {
    hideGame()
    let front = stage.frame.makeIcon().sca(0.8);
    let answer = winnings.value[winningsIndex++];
    let back = new Rectangle(front.width, front.height, answer);
    let card = new Flipper(front, back, null, null, null, null, null, false, false).centerReg({ add: false });
    card.answer = answer;
    return card;
} async function showWinnings() {
    await store.dispatch("getWinnings")
    console.log("winnings: ", winnings.value)
    if (cardsContainer) {
        cardsContainer.removeFrom()
    }
    const winningsLength = winnings.value.length;
    const cols = Math.floor(Math.sqrt(winningsLength)); // Calculate columns based on the square root of the length
    const rows = Math.floor(winningsLength / cols); // Calculate rows based on the total number of items and columns
    console.log(cols, rows)
    cardsContainer = new Tile({
        obj: makeCard,
        cols: cols,
        rows: rows,
        spacingH: 20,
        spacingV: 15,
        clone: false // so keeps proper answer
    }).center().cur();
    let revealDelay = 0.5; // Delay in seconds
    cardsContainer.loop((card, i) => {
        timeout(i * revealDelay, () => {
            card.flip();
        });
    });
    loadingAnimation = new Container(window.innerWidth, window.innerHeight).addTo();
    new Blob({
        controlType: "none",
        points: new Rectangle(200, 200),
        color: green,
        interactive: false,
    })
        .center(loadingAnimation)
        .sca(5, 4)
        .sha("rgba(0,0,0,.3)", 10, 15, 10);
    mainMenu = new Pane({
        label: "",
        color: white,
        backing: loadingAnimation,
        displayClose: false,
        backdropClose: false,
    }).show();
    mainMenu.mov(0, -20)
    const winningsTitle = new Label({
        text: "Your Winings",
        size: 40,
        color: 'black',
    });
    const score = new Label({
        text: `Score: ${store.state.score}`,
        size: 40,
        color: 'black',
    });
    const time = new Label({
        text: `Time left: ${timer.time}`,
        size: 40,
        color: 'black',
    });
    // Create the Claim button
    const claimButton = new Button({
        label: "Claim",
        corner: 0,
        color: white,
        backgroundColor: yellow,
        rollBackgroundColor: green,
        corner: 40
    }).addTo(mainMenu).tap(async function () {
        await store.dispatch("claimWinnings")
    });
    const toMenuButton = new Button({
        label: "Goto Menu",
        corner: 0,
        color: white,
        backgroundColor: green,
        rollBackgroundColor: yellow,
        corner: 40
    }).addTo(mainMenu).tap(async function () {
        createGame()
    });
    // Position the Claim button at the bottom of the mainMenu
    claimButton.pos(120, mainMenu.height + 220, BOTTOM);
    toMenuButton.pos(-120, mainMenu.height + 220, BOTTOM);

    winningsTitle.pos(600, mainMenu.height - 130, BOTTOM);
    score.pos(250, mainMenu.height + 110, BOTTOM);
    time.pos(250, mainMenu.height + 150, BOTTOM);
    cardsContainer.center(mainMenu).mov(200, 0);
    stage.update();
}

onMounted(() => {
    createGame()
});

onBeforeUnmount(() => {
    frame.value.dispose();
});

</script>

<style scoped>
#zim {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    overflow: hidden;
    margin: 0;
    padding: 0;
}

html,
body {
    width: 100%;
    height: 100%;
    margin: 0;
    padding: 0;
    overflow: hidden;
}

canvas {
    display: block;
    /* Ensures the canvas does not add extra space */
    margin: 0;
    padding: 0;
    position: absolute;
    /* Ensure it is positioned absolutely */
    width: 100%;
    /* Scale to 100% of its container */
    height: 100%;
    /* Scale to 100% of its container */
}
</style>