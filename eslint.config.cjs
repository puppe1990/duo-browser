const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  { ignores: ['node_modules/**', 'src-tauri/**', 'native/DuoNative.app/**'] },
  js.configs.recommended,
  { files: ['**/*.cjs'], languageOptions: { globals: globals.node } },
  {
    files: ['web/*.js', 'native/page-input.js', 'brave-extension/*.js'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['brave-extension/protocol.js', 'brave-extension/bridge.js'],
    languageOptions: { globals: { module: 'readonly' } },
  },
  {
    files: ['native/page-input.js'],
    languageOptions: { globals: { editText: 'readonly' } },
  },
];
