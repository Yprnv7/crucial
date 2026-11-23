/* --------------------------------------------------------------------------
   Crucial: Client-side Interactive Engine
   -------------------------------------------------------------------------- */

document.addEventListener('DOMContentLoaded', () => {
  // 1. macOS Demo Window Tab Switching
  const tabButtons = document.querySelectorAll('.tab-btn');
  const demoScreens = document.querySelectorAll('.demo-screen');

  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');

      // Update button state
      tabButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      // Update screen state
      demoScreens.forEach(screen => {
        screen.classList.remove('active');
        if (screen.id === `tab-${targetTab}`) {
          screen.classList.add('active');
        }
      });
    });
  });

  // 2. Showcase Video Player Controller
  const video = document.getElementById('crucial-video');
  const playBtn = document.getElementById('video-play-btn');
  const playText = document.getElementById('play-text');
  const playIcon = document.getElementById('play-icon');
  const timeDisplay = document.getElementById('video-time');
  const soundBtn = document.getElementById('video-sound-btn');
  const soundText = document.getElementById('sound-text');
  const soundIcon = document.getElementById('sound-icon');

  if (video && playBtn) {
    // Autoplay when visible
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          video.play().catch(() => {});
        } else {
          video.pause();
        }
      });
    }, { threshold: 0.3 });
    observer.observe(video);

    // Play/Pause button toggle
    playBtn.addEventListener('click', () => {
      if (video.paused) {
        video.play();
        playText.textContent = "Pause Showcase";
        playIcon.innerHTML = `<rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect>`;
      } else {
        video.pause();
        playText.textContent = "Play Showcase";
        playIcon.innerHTML = `<polygon points="5 3 19 12 5 21 5 3"></polygon>`;
      }
    });

    video.addEventListener('play', () => {
      playText.textContent = "Pause Showcase";
      playIcon.innerHTML = `<rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect>`;
    });

    video.addEventListener('pause', () => {
      playText.textContent = "Play Showcase";
      playIcon.innerHTML = `<polygon points="5 3 19 12 5 21 5 3"></polygon>`;
    });

    // Time counter (exact 30.0s format)
    video.addEventListener('timeupdate', () => {
      const cur = Math.floor(video.currentTime);
      const curSec = cur < 10 ? `0${cur}` : cur;
      timeDisplay.textContent = `0:${curSec} / 0:30`;
    });

    // Sound toggle
    if (soundBtn) {
      soundBtn.addEventListener('click', () => {
        video.muted = !video.muted;
        if (video.muted) {
          soundText.textContent = "Unmute";
          soundIcon.innerHTML = `
            <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon>
            <line x1="23" y1="9" x2="17" y2="15"></line>
            <line x1="17" y1="9" x2="23" y2="15"></line>
          `;
        } else {
          soundText.textContent = "Mute";
          soundIcon.innerHTML = `
            <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon>
            <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path>
          `;
        }
      });
    }
  }

  // 3. FAQ Accordion Logic
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    question.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      // Close others
      faqItems.forEach(i => i.classList.remove('open'));
      // Toggle target
      if (!isOpen) {
        item.classList.add('open');
      }
    });
  });

  // Open first FAQ by default
  if (faqItems.length > 0) {
    faqItems[0].classList.add('open');
  }
});
