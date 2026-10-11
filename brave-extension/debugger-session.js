class BraveSession {
  constructor(api, tabId, onDetached) {
    this.api = api;
    this.target = { tabId };
    this.attached = false;
    this.onDetached = onDetached;
    this.listener = (target, reason) => {
      if (target.tabId === tabId) this.disconnect(reason);
    };
    api.onDetach.addListener(this.listener);
  }

  async attach() {
    if (this.attached) return;
    await this.api.attach(this.target, '1.3');
    this.attached = true;
  }

  async command(method, params = {}) {
    if (!this.attached)
      throw new Error('Brave desconectado; reative no controle Duo');
    try {
      return await this.api.sendCommand(this.target, method, params);
    } catch (error) {
      if (/not attached|No tab with given id/i.test(error.message))
        this.disconnect('connection_lost');
      throw error;
    }
  }

  disconnect(reason) {
    if (!this.attached) return;
    this.attached = false;
    this.onDetached(reason);
  }

  async close() {
    this.api.onDetach.removeListener(this.listener);
    const wasAttached = this.attached;
    this.attached = false;
    if (wasAttached) await this.api.detach(this.target).catch(() => {});
  }
}

if (typeof module !== 'undefined') module.exports = { BraveSession };
