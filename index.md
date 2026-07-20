---
layout: default
title: Tick
---

<section class="hero" aria-labelledby="hero-title">
  <div class="hero__copy">
    <p class="eyebrow">iPhone + iPad <span aria-hidden="true">·</span> Lightweight timekeeping</p>
    <h1 id="hero-title">See where your time actually goes.</h1>
    <p class="hero__lede">Tick makes time capture immediate: choose a Space, start the clock, and get on with it. Titles, notes, and missed time can wait until later.</p>
    <div class="hero__actions">
      <a class="button button--primary" href="{{ site.github_url }}">View on GitHub <span aria-hidden="true">↗</span></a>
      <a class="button button--quiet" href="#tick-flow">See how a Tick works</a>
    </div>
    <ul class="signal-list" aria-label="Project foundation">
      <li>SwiftUI</li>
      <li>iPhone + iPad</li>
      <li>Local JSON</li>
      <li>WidgetKit</li>
    </ul>
  </div>

  <aside class="status-card" aria-labelledby="build-status-title">
    <div class="status-card__topline">
      <span class="status-pill"><span class="status-dot" aria-hidden="true"></span>{{ site.status_label }}</span>
      <span class="status-card__meta">Today</span>
    </div>
    <div class="house-mark" aria-hidden="true">
      <span></span><span></span><span></span><span></span>
    </div>
    <p class="status-card__kicker">Current app</p>
    <h2 id="build-status-title">Capture first.<br>Explain it later.</h2>
    <dl class="status-list">
      <div><dt>Start + Stop</dt><dd>Ready</dd></div>
      <div><dt>Manual time</dt><dd>Ready</dd></div>
      <div><dt>Auto Ticks</dt><dd>Opt-in</dd></div>
    </dl>
  </aside>
</section>

<section class="section" aria-labelledby="principles-title">
  <div class="section-heading">
    <p class="eyebrow">Timekeeping without timesheets</p>
    <h2 id="principles-title">The record can be useful without becoming work.</h2>
    <p>Tick keeps capture fast and detail optional, then turns those small records into a clear picture of today, this week, or the month.</p>
  </div>

  <div class="principle-grid">
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">01</span>
      <h3>Start immediately</h3>
      <p>Choose a Space and start one active Tick without filling out a form or deciding what the session means yet.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">02</span>
      <h3>Organize around Spaces</h3>
      <p>Keep sessions, notes, voice memos, and Auto Tick rules attached to the place or part of life they belong to.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">03</span>
      <h3>Review the real pattern</h3>
      <p>Daily, weekly, and monthly summaries show recorded time without asking you to maintain a complicated system.</p>
    </article>
  </div>
</section>

<section class="section section--split" id="tick-flow" aria-labelledby="today-title">
  <article class="resident-card">
    <div class="resident-card__header">
      <div class="resident-icon" aria-hidden="true">
        <span></span><span></span><span></span>
      </div>
      <div>
        <p class="eyebrow">Today’s Ticks</p>
        <h2 id="today-title">One clock, right when you need it</h2>
      </div>
    </div>
    <p class="resident-card__summary">Today keeps the active timer, recorded sessions, and total time together. Start and stop stay prominent; cleanup can happen when there is room for it.</p>
    <div class="boundary-note">
      <strong>Capture from the app or widget</strong>
      <span>Today · Spaces · Auto Ticks · Summaries</span>
    </div>
    <ul class="capability-list">
      <li><span aria-hidden="true">✓</span> One active timer at a time</li>
      <li><span aria-hidden="true">✓</span> Add missed time manually</li>
      <li><span aria-hidden="true">✓</span> Edit the Space, title, and notes later</li>
      <li><span aria-hidden="true">✓</span> Archive a Space without losing history</li>
    </ul>
  </article>

  <div class="run-flow" aria-labelledby="flow-title">
    <p class="eyebrow">A lightweight record</p>
    <h2 id="flow-title">Start now. Make sense of it later.</h2>
    <ol>
      <li><span>01</span><div><strong>Choose a Space</strong><p>Pick where this time belongs.</p></div></li>
      <li><span>02</span><div><strong>Start Tick</strong><p>Begin immediately with one tap.</p></div></li>
      <li><span>03</span><div><strong>Do the thing</strong><p>The clock runs without constant writes.</p></div></li>
      <li><span>04</span><div><strong>Stop Tick</strong><p>Save the completed session.</p></div></li>
      <li><span>05</span><div><strong>Add context</strong><p>Title it or leave a note when useful.</p></div></li>
      <li><span>06</span><div><strong>Review the pattern</strong><p>See daily, weekly, and monthly totals.</p></div></li>
    </ol>
  </div>
</section>

<section class="section foundation" aria-labelledby="foundation-title">
  <div>
    <p class="eyebrow">Local first. Location only by choice.</p>
    <h2 id="foundation-title">Your time record stays dependable.</h2>
  </div>
  <p>Tick writes atomically to the shared App Group container and mirrors its snapshot through iCloud KVS for your iPhone, iPad, and widgets. Auto Ticks request location only after you opt in, monitor enabled saved regions, and do not keep route or visit history.</p>
</section>
