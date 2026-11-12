// Vertical slice: no ad or billing SDK, network calls, or synthetic purchase grants.
export const ads = {
  available: false,
  async showRewarded() {
    return { rewarded: false, reason: "unavailable" };
  },
  async showInterstitial() {
    return false;
  },
};
export const billing = {
  available: false,
  async purchase() {
    return { purchased: false, reason: "unavailable" };
  },
  async restore() {
    return [];
  },
};
