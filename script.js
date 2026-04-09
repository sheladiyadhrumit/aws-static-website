// =============================================
//  CloudOps — Static Website for AWS Deployment
//  script.js
// =============================================

// ── 1. NAV: add .scrolled class on scroll ──────────────────────────────────
const nav = document.getElementById('nav');

window.addEventListener('scroll', () => {
  if (window.scrollY > 30) {
    nav.classList.add('scrolled');
  } else {
    nav.classList.remove('scrolled');
  }
}, { passive: true });


// ── 2. TERMINAL ANIMATION ──────────────────────────────────────────────────
const terminalEl = document.getElementById('terminal');

// Lines that will print one by one, each with a delay and CSS class for color
const terminalLines = [
  { text: '$ git push origin main',               cls: 't-white', delay: 300  },
  { text: 'Enumerating objects: 12, done.',        cls: 't-dim',   delay: 800  },
  { text: 'Writing objects: 100% (12/12)',         cls: 't-dim',   delay: 1200 },
  { text: 'To https://github.com/user/static-website-aws', cls: 't-dim', delay: 1500 },
  { text: '   a3f9d1c..e7b2a8f  main → main',     cls: 't-green', delay: 1800 },
  { text: '',                                      cls: '',        delay: 2000 },
  { text: '🔔 Webhook received by Jenkins...',    cls: 't-amber', delay: 2300 },
  { text: 'Started pipeline: static-website-aws', cls: 't-dim',   delay: 2700 },
  { text: '',                                      cls: '',        delay: 2900 },
  { text: '[Stage 1] Checkout SCM',               cls: 't-blue',  delay: 3100 },
  { text: '  ✓ Cloned repo successfully',         cls: 't-green', delay: 3500 },
  { text: '',                                      cls: '',        delay: 3700 },
  { text: '[Stage 2] Build Docker Image',         cls: 't-blue',  delay: 3900 },
  { text: '  docker build -t my-website:latest .', cls: 't-dim',  delay: 4200 },
  { text: '  Step 1/3 : FROM nginx:alpine',       cls: 't-dim',   delay: 4500 },
  { text: '  Step 2/3 : COPY . /usr/share/nginx/html', cls: 't-dim', delay: 4800 },
  { text: '  Step 3/3 : EXPOSE 80',              cls: 't-dim',   delay: 5100 },
  { text: '  ✓ Successfully built image',         cls: 't-green', delay: 5500 },
  { text: '',                                      cls: '',        delay: 5700 },
  { text: '[Stage 3] Deploy Container',           cls: 't-blue',  delay: 5900 },
  { text: '  Stopping old container...',          cls: 't-dim',   delay: 6200 },
  { text: '  Starting new container on :80',      cls: 't-dim',   delay: 6500 },
  { text: '  ✓ Container live and healthy',       cls: 't-green', delay: 6900 },
  { text: '',                                      cls: '',        delay: 7100 },
  { text: '✅ Pipeline SUCCESS — 00:02:34',       cls: 't-green', delay: 7400 },
  { text: '$ _',                                  cls: 't-white', delay: 7800 },
];

// Print each line after its delay, then loop the whole sequence
function runTerminal() {
  terminalEl.innerHTML = '';

  terminalLines.forEach((line, i) => {
    setTimeout(() => {
      const span = document.createElement('span');
      span.className = `t-line ${line.cls}`;

      // Last line gets a blinking cursor appended
      if (i === terminalLines.length - 1) {
        span.innerHTML = line.text.replace('_', '') + '<span class="cursor"></span>';
      } else {
        span.textContent = line.text;
      }

      terminalEl.appendChild(span);

      // Auto-scroll terminal to bottom
      terminalEl.scrollTop = terminalEl.scrollHeight;
    }, line.delay);
  });

  // Total duration of all lines + pause, then restart
  const lastDelay = terminalLines[terminalLines.length - 1].delay;
  setTimeout(runTerminal, lastDelay + 4000);
}

runTerminal();


// ── 3. METRIC COUNTER ANIMATION ───────────────────────────────────────────
// Counts numbers up to their target value when they scroll into view

const metricEls = document.querySelectorAll('.metric-val[data-target]');

function animateCounter(el) {
  const target  = parseFloat(el.dataset.target);
  const isFloat = target % 1 !== 0;          // e.g. 99.9
  const duration = 1800;                      // ms
  const steps    = 60;
  const stepTime = duration / steps;
  let current    = 0;
  let step       = 0;

  const timer = setInterval(() => {
    step++;
    current = target * (step / steps);

    if (isFloat) {
      el.textContent = current.toFixed(1);
    } else {
      el.textContent = Math.floor(current);
    }

    if (step >= steps) {
      clearInterval(timer);
      el.textContent = isFloat ? target.toFixed(1) : target;
    }
  }, stepTime);
}

// Use IntersectionObserver so the counter fires when visible
const counterObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      animateCounter(entry.target);
      counterObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.5 });

metricEls.forEach(el => counterObserver.observe(el));


// ── 4. STACK CARDS — staggered fade-in on scroll ──────────────────────────
const stackCards = document.querySelectorAll('.stack-card');

const cardObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const delay = parseInt(entry.target.dataset.delay || '0', 10);
      setTimeout(() => {
        entry.target.classList.add('visible');
      }, delay);
      cardObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.15 });

stackCards.forEach(card => cardObserver.observe(card));


// ── 5. PIPELINE STEPS — staggered appear on scroll ────────────────────────
const pipelineSteps = document.querySelectorAll('.pipeline-step');

const pipelineObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const stepIndex = parseInt(entry.target.dataset.step || '1', 10);
      setTimeout(() => {
        entry.target.classList.add('visible');
      }, (stepIndex - 1) * 150);
      pipelineObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.2 });

pipelineSteps.forEach(step => pipelineObserver.observe(step));


// ── 6. FOOTER: show deploy time ────────────────────────────────────────────
// Shows how long ago the page was "deployed" (just uses the current date
// as a placeholder — in a real deployment you'd inject this via Jenkins)
const deployTimeEl = document.getElementById('deploy-time');

if (deployTimeEl) {
  const now = new Date();
  const options = { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
  deployTimeEl.textContent = now.toLocaleDateString('en-US', options);
}


// ── 7. SMOOTH SECTION HIGHLIGHT on scroll (active nav links) ──────────────
const sections   = document.querySelectorAll('section[id]');
const navAnchors = document.querySelectorAll('.nav-links a[href^="#"]');

const sectionObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      navAnchors.forEach(a => {
        a.style.color = '';
        if (a.getAttribute('href') === `#${entry.target.id}`) {
          a.style.color = 'var(--text)';
        }
      });
    }
  });
}, { threshold: 0.4 });

sections.forEach(s => sectionObserver.observe(s));
