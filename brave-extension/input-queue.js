class BraveInputQueue {
  constructor(dispatch, onError = () => {}) {
    this.dispatch = dispatch;
    this.onError = onError;
    this.move = null;
    this.actions = [];
    this.moving = false;
    this.acting = false;
  }

  push(message) {
    if (message.kind === 'move') {
      this.move = message;
      void this.flushMoves();
      return;
    }
    this.move = null;
    this.actions.push(message);
    void this.flushActions();
  }

  async deliver(message) {
    try {
      await this.dispatch(message);
    } catch (error) {
      this.onError(error);
    }
  }

  async flushMoves() {
    if (this.moving) return;
    this.moving = true;
    while (this.move) {
      const message = this.move;
      this.move = null;
      await this.deliver(message);
    }
    this.moving = false;
  }

  async flushActions() {
    if (this.acting) return;
    this.acting = true;
    while (this.actions.length) await this.deliver(this.actions.shift());
    this.acting = false;
  }
}

if (typeof module !== 'undefined') module.exports = { BraveInputQueue };
