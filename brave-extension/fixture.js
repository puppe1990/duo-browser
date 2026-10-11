document.querySelector('#fixture').addEventListener('click', (event) => {
  document.body.dataset.trustedClick = String(event.isTrusted);
});
