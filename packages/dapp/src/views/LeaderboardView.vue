<template>
  <div class="leaderboard">
    <h1 class="leaderboard-title">
      LEADERBOARD
    </h1>
    <h2 class="leaderboard-subtitle">
      GAME NAME HERE
    </h2>
    <div class="leaderboard-header">
      <span class="header-rank">RANK</span>
      <span class="header-name">PLAYER NAME</span>
      <span class="header-chain">CHAIN</span>
      <span class="header-score">SCORE</span>
    </div>
    <ol class="leaderboard-list">
      <li v-for="(player, index) in players" :key="index" :class="{ 'top-three': index < 3 }">
        <span class="rank">{{ index + 1 }}</span>
        <span class="name">{{ player.name }}</span>
        <span class="chain">{{ player.chain }}</span>
        <span class="score">{{ player.score }}</span>
      </li>
    </ol>
  </div>
</template>

<script>
export default {
  name: 'Leaderboard',
  data() {
    return {
      players: [
        { name: '0x388C818CA8B9251b393131C08a736A67ccB19297', score: 58, chain: 11155111 },
        { name: '0x388C818CA8B9251b393131C08a736A67ccB19297', score: 56, chain: 11155111 },
        { name: '0x388C818CA8B9251b393131C08a736A67ccB19297', score: 55, chain: 11155111 },
        { name: '0x388C818CA8B9251b393131C08a736A67ccB19297', score: 50, chain: 421614 },
        { name: '0x388C818CA8B9251b393131C08a736A67ccB19297', score: 49, chain: 421614 },
        { name: '0X388C818CA8B9251B393131C08A736A67CCB19297', score: 46, chain: 421614 },
        { name: '0X388C818CA8B9251B393131C08A736A67CCB19297', score: 44, chain: 421614 },
        { name: '0X388C818CA8B9251B393131C08A736A67CCB19297', score: 42, chain: 421614 },
        { name: '0X388C818CA8B9251B393131C08A736A67CCB19297', score: 40, chain: 421614 },
        { name: '0X388C818CA8B9251B393131C08A736A67CCB19297', score: 38, chain: 11155111 },
      ],
    };
  },
};
</script>

<style scoped>
.leaderboard {
  width: 600px;
  margin: 0 auto;
  padding: 20px;
  text-align: center;
}

.leaderboard-title {
  font-size: 32px;
  font-weight: bold;
}

.leaderboard-subtitle {
  font-size: 18px;
  margin-bottom: 20px;
}

.leaderboard-header {
  display: grid;
  grid-template-columns: 1fr 2fr 1fr 1fr;
  font-weight: bold;
  margin-bottom: 10px;
}

.leaderboard-list {
  list-style-type: none;
  padding: 0;
  margin: 0;
}

.leaderboard-list li {
  display: grid;
  grid-template-columns: 1fr 2fr 1fr 1fr;
  align-items: center;
  padding: 10px;
  border: 1px solid #ccc;
  margin-bottom: 10px;
}

.leaderboard-list li.top-three {
  background-color: #e0e0e0;
}

.rank {
  font-weight: bold;
}

.name {
  text-align: left;
}

.chain {
  text-align: center;
}

.score {
  font-weight: bold;
}
</style>