const { test } = require('node:test');
const assert = require('node:assert/strict');
const { editText } = require('../native/virtual-input.cjs');

test('inserts at selection and replaces selected text', () => {
  assert.deepEqual(editText('olá mundo', 4, 9, 'você'), { value: 'olá você', caret: 8 });
});
test('backspace deletes selection or previous character, including emoji', () => {
  assert.deepEqual(editText('abc', 1, 3, 'Backspace'), { value: 'a', caret: 1 });
  assert.deepEqual(editText('a😀', 3, 3, 'Backspace'), { value: 'a', caret: 1 });
  assert.deepEqual(editText('abc', 0, 0, 'Backspace'), { value: 'abc', caret: 0 });
});
