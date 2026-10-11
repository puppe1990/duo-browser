function editText(value, start, end, key) {
  let from = start;
  const insertion = key === 'Backspace' ? '' : key;
  if (key === 'Backspace' && start === end && start > 0) {
    from -= [...value.slice(0, start)].at(-1).length;
  }
  return { value: value.slice(0, from) + insertion + value.slice(end), caret: from + insertion.length };
}
if (typeof module !== 'undefined') module.exports = { editText };
