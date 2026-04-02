// Help offcanvas resize functionality
// Allows users to drag the left edge to resize the help panel width

(function() {
  'use strict';

  let isResizing = false;
  let startX = 0;
  let startWidth = 0;
  let panel = null;

  const MIN_WIDTH = 300;
  const MAX_WIDTH = Math.min(900, window.innerWidth * 0.8);
  const DEFAULT_WIDTH = 400;

  function initResize() {
    const handles = document.querySelectorAll('.help-resize-handle');
    
    handles.forEach(function(handle) {
      if (handle.dataset.resizeInit) return;
      handle.dataset.resizeInit = 'true';

      handle.addEventListener('mousedown', startResize);
      handle.addEventListener('touchstart', startResizeTouch, { passive: false });
    });
  }

  function startResize(e) {
    e.preventDefault();
    panel = e.target.closest('.help-offcanvas-resizable');
    if (!panel) return;

    isResizing = true;
    startX = e.clientX;
    startWidth = panel.offsetWidth;

    document.body.style.cursor = 'ew-resize';
    document.body.style.userSelect = 'none';

    document.addEventListener('mousemove', doResize);
    document.addEventListener('mouseup', stopResize);
  }

  function startResizeTouch(e) {
    if (e.touches.length !== 1) return;
    e.preventDefault();
    
    panel = e.target.closest('.help-offcanvas-resizable');
    if (!panel) return;

    isResizing = true;
    startX = e.touches[0].clientX;
    startWidth = panel.offsetWidth;

    document.addEventListener('touchmove', doResizeTouch, { passive: false });
    document.addEventListener('touchend', stopResize);
  }

  function doResize(e) {
    if (!isResizing || !panel) return;
    
    // For offcanvas-end, dragging left increases width
    const deltaX = startX - e.clientX;
    const newWidth = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, startWidth + deltaX));
    
    panel.style.width = newWidth + 'px';
  }

  function doResizeTouch(e) {
    if (!isResizing || !panel || e.touches.length !== 1) return;
    e.preventDefault();
    
    const deltaX = startX - e.touches[0].clientX;
    const newWidth = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, startWidth + deltaX));
    
    panel.style.width = newWidth + 'px';
  }

  function stopResize() {
    isResizing = false;
    panel = null;

    document.body.style.cursor = '';
    document.body.style.userSelect = '';

    document.removeEventListener('mousemove', doResize);
    document.removeEventListener('mouseup', stopResize);
    document.removeEventListener('touchmove', doResizeTouch);
    document.removeEventListener('touchend', stopResize);
  }

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initResize);
  } else {
    initResize();
  }

  // Re-initialize when Shiny adds new elements (for dynamic UI)
  if (typeof Shiny !== 'undefined') {
    $(document).on('shiny:value', function() {
      setTimeout(initResize, 100);
    });
  }

  // Also watch for Bootstrap offcanvas show events
  document.addEventListener('shown.bs.offcanvas', function(e) {
    if (e.target.classList.contains('help-offcanvas-resizable')) {
      initResize();
    }
  });
})();
