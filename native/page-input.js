(() => {
  let target = null;
  let hovered = null;
  window.__duo = (kind, x, y, key) => {
    const element = document.elementFromPoint(x, y);
    if (kind === 'move' && element) {
      if (hovered !== element) {
        hovered?.dispatchEvent(new MouseEvent('mouseout', { bubbles: true }));
        element.dispatchEvent(new MouseEvent('mouseover', { bubbles: true, clientX: x, clientY: y }));
        hovered = element;
      }
      element.dispatchEvent(new MouseEvent('mousemove', { bubbles: true, clientX: x, clientY: y }));
    }
    if (kind === 'click' && element) {
      target = element.closest('input,textarea,[contenteditable="true"]');
      if (target) target.focus({ preventScroll: true });
      for (const event of ['mousedown', 'mouseup', 'click']) {
        element.dispatchEvent(new MouseEvent(event, { bubbles: true, clientX: x, clientY: y }));
      }
    }
    if (kind === 'scroll') {
      let scroller = element;
      while (scroller && scroller !== document.documentElement && scroller.scrollHeight <= scroller.clientHeight) scroller = scroller.parentElement;
      (scroller || document.scrollingElement)?.scrollBy(0, -key * 48);
    }
    if (kind !== 'key' || !target || !target.isConnected || target.disabled || target.readOnly) return;
    if (key === 'Enter') {
      if (target.tagName === 'TEXTAREA') key = '\n';
      else { target.closest('form')?.requestSubmit(); return; }
    }
    if (target.isContentEditable) {
      target.focus();
      document.execCommand(key === 'Backspace' ? 'delete' : 'insertText', false, key === 'Backspace' ? null : key);
      return;
    }
    const start = target.selectionStart ?? target.value.length;
    const end = target.selectionEnd ?? start;
    const edited = editText(target.value, start, end, key);
    const prototype = target.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(prototype, 'value').set.call(target, edited.value);
    try { target.setSelectionRange(edited.caret, edited.caret); } catch {}
    target.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: key === 'Backspace' ? 'deleteContentBackward' : 'insertText', data: key }));
    target.dispatchEvent(new Event('change', { bubbles: true }));
  };
})();
