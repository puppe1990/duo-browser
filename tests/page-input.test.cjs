const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { editText } = require('../native/virtual-input.cjs');

function page({ disabled = false, readOnly = false } = {}) {
  const events = [];
  class Input {
    constructor() {
      this.tagName = 'INPUT';
      this.type = 'text';
      this.isConnected = true;
      this.disabled = disabled;
      this.readOnly = readOnly;
      this.selectionStart = 1;
      this.selectionEnd = 2;
      this._value = 'abc';
    }
    get value() {
      return this._value;
    }
    set value(text) {
      this._value = text;
    }
    closest(selector) {
      return selector === 'form'
        ? {
            requestSubmit() {
              events.push('submit');
            },
          }
        : this;
    }
    focus() {
      events.push('focus');
    }
    dispatchEvent(event) {
      events.push(event.type);
    }
    setSelectionRange(start, end) {
      this.selectionStart = start;
      this.selectionEnd = end;
    }
  }
  const field = new Input();
  const context = {
    window: {},
    editText,
    HTMLInputElement: Input,
    HTMLTextAreaElement: Input,
    MouseEvent: class {
      constructor(type) {
        this.type = type;
      }
    },
    InputEvent: class {
      constructor(type) {
        this.type = type;
      }
    },
    Event: class {
      constructor(type) {
        this.type = type;
      }
    },
    document: {
      createElement: () => {
        events.push('cursor-created');
        return { style: {} };
      },
      documentElement: { append() {} },
      elementFromPoint: () => field,
    },
  };
  vm.runInNewContext(fs.readFileSync('native/page-input.js', 'utf8'), context);
  return { send: context.window.__duo, field, events };
}

test('virtual keyboard edits selected field and emits input for reactive sites', () => {
  const { send, field, events } = page();
  send('click', 4, 5);
  send('key', 4, 5, 'X');
  assert.equal(field.value, 'aXc');
  assert.ok(events.includes('input'));
  send('key', 4, 5, 'Enter');
  assert.ok(events.includes('submit'));
});
test('virtual keyboard never edits disabled or readonly fields', () => {
  for (const options of [{ disabled: true }, { readOnly: true }]) {
    const { send, field } = page(options);
    send('click', 4, 5);
    send('key', 4, 5, 'X');
    assert.equal(field.value, 'abc');
  }
});
test('page never draws a duplicate cursor over the native seat cursor', () => {
  assert.ok(!page().events.includes('cursor-created'));
});
