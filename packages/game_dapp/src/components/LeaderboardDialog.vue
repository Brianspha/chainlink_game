<template>
  <v-container fluid>
    <v-dialog
      v-model="$store.state.showLeaderBoard"
      width="auto"
    >
      <v-card text="Cross chain leaderboard">
        <v-card-item>
          <LeaderboardView />
        </v-card-item>
        <template #actions>
          <v-btn
            class="ms-auto"
            text="Ok"
            @click="$store.state.showLeaderBoard = false"
          />
        </template>
      </v-card>
    </v-dialog>
  </v-container>
</template>
<script>
import LeaderboardView from "../views/LeaderboardView.vue"
export default {
    components: {
        LeaderboardView
    },
    data() {
        return {
            dialog: false,
        }
    },
}
</script>
<style scoped>
body {
    overflow: hidden; /* Hide scrollbars */

}
</style>