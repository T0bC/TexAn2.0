// Plot resize handler for ggiraph outputs
// Reports container size to Shiny for dynamic SVG sizing

// Debounce function to limit the rate at which a function can fire
function debounce(func, wait, immediate) {
    var timeout;
    return function () {
        var context = this, args = arguments;
        var later = function () {
            timeout = null;
            if (!immediate) func.apply(context, args);
        };
        var callNow = immediate && !timeout;
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
        if (callNow) func.apply(context, args);
    };
}

// Initialize container size reporting for a specific module
// targetId: the namespaced ID of the plots container (e.g., "plotting-plots")
// windowInputId: the namespaced input ID to send size to
function initializeWindowSize(targetId, windowInputId) {

    // Track last reported size to avoid duplicate updates
    var lastWidth = null;
    var lastHeight = null;

    // Function to report container size to Shiny (only if changed)
    var reportContainerSize = function () {
        if (window.Shiny && Shiny.setInputValue) {
            // Try to find the plots container element
            var container = document.getElementById(targetId);
            var currentWidth, currentHeight;

            if (container && container.offsetWidth > 0) {
                // Use actual container width (accounts for sidebar, padding, etc.)
                currentWidth = container.offsetWidth;
                currentHeight = container.offsetHeight || window.innerHeight;
            } else {
                // Fallback: estimate based on window width minus typical sidebar
                // bslib sidebar is typically ~300px
                currentWidth = Math.max(400, window.innerWidth - 350);
                currentHeight = window.innerHeight;
            }

            // Only send if values actually changed
            if (currentWidth !== lastWidth || currentHeight !== lastHeight) {
                lastWidth = currentWidth;
                lastHeight = currentHeight;

                Shiny.setInputValue(windowInputId, {
                    width: currentWidth,
                    height: currentHeight
                });
            }
        }
    };

    // Debounced version (250ms delay for resize dragging)
    var debouncedReportSize = debounce(reportContainerSize, 250);

    // Update on window resize
    $(window).on('resize', debouncedReportSize);

    // Report on tab switches (but not on every visual change)
    $(document).on('shown.bs.tab', function () {
        setTimeout(reportContainerSize, 50);
    });

    // Initial report after page load
    $(document).on('shiny:connected', function () {
        setTimeout(reportContainerSize, 100);
    });

    // Also observe sidebar toggle (bslib sidebar can be collapsed)
    $(document).on('click', '[data-bs-toggle="collapse"]', function () {
        setTimeout(reportContainerSize, 350);
    });
}
