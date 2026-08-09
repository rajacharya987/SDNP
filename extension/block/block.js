document.addEventListener('DOMContentLoaded', () => {
  const urlParams = new URLSearchParams(window.location.search);
  const blockedUrl = urlParams.get('url') || 'http://example-bank-login.com';
  const score = urlParams.get('score') || '94';
  const reasonsParam = urlParams.get('reasons');

  const targetBox = document.getElementById('targetUrlBox');
  const scoreEl = document.getElementById('scoreValue');
  const reasonsList = document.getElementById('reasonsList');
  const goBackBtn = document.getElementById('goBackBtn');
  const proceedBtn = document.getElementById('proceedUnsafeBtn');

  if (targetBox) targetBox.textContent = blockedUrl;
  if (scoreEl) scoreEl.textContent = `${score}/100 🔴`;

  if (reasonsParam && reasonsList) {
    try {
      const parsedReasons = JSON.parse(reasonsParam);
      if (Array.isArray(parsedReasons) && parsedReasons.length > 0) {
        reasonsList.innerHTML = '';
        parsedReasons.forEach(r => {
          const li = document.createElement('li');
          li.textContent = `✓ ${r}`;
          reasonsList.appendChild(li);
        });
      }
    } catch (e) {
      console.warn('Failed to parse reasons parameter', e);
    }
  }

  if (goBackBtn) {
    goBackBtn.addEventListener('click', () => {
      if (window.history.length > 1) {
        window.history.back();
      } else {
        window.location.href = 'https://www.google.com';
      }
    });
  }

  if (proceedBtn) {
    proceedBtn.addEventListener('click', () => {
      if (confirm('WARNING: Proceeding to this page may expose your passwords or personal data to scammers. Are you sure?')) {
        window.location.href = blockedUrl;
      }
    });
  }
});
