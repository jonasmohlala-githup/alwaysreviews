// Accordion (item 3)
document.querySelectorAll('.accordion__item').forEach(btn => {
  btn.addEventListener('click', () => {
    const panel = document.getElementById(btn.dataset.target);
    const isOpen = btn.classList.contains('is-open');

    document.querySelectorAll('.accordion__item').forEach(other => {
      other.classList.remove('is-open');
      document.getElementById(other.dataset.target).style.maxHeight = null;
    });

    if (!isOpen) {
      btn.classList.add('is-open');
      panel.style.maxHeight = panel.scrollHeight + 'px';
    }
  });
});

// Back to top button
const backToTop = document.getElementById('backToTop');
window.addEventListener('scroll', () => {
  if (window.scrollY > 600) {
    backToTop.classList.add('is-visible');
  } else {
    backToTop.classList.remove('is-visible');
  }
});
backToTop.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});
