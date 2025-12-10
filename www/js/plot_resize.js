// Plot resize handler for ggiraph outputs
// Reports actual container dimensions to Shiny for dynamic SVG sizing
// Measures the plot container element directly, not window size

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
    // Measures the actual plot container dimensions for accurate SVG sizing
    var reportWindowSize = function () {
        if (window.Shiny && Shiny.setInputValue) {
            var container = document.getElementById(targetId);
            var currentWidth;
            var currentHeight;

            if (container && container.offsetWidth > 0) {
                // Use actual container dimensions
                currentWidth = container.offsetWidth;
                // For height: use container height if available, otherwise calculate from viewport
                // Subtract header/padding estimates for card chrome
                var containerHeight = container.offsetHeight;
                if (containerHeight > 100) {
                    currentHeight = containerHeight;
                } else {
                    // Container not yet sized - estimate from viewport minus UI chrome
                    currentHeight = window.innerHeight - 200;
                }
            } else {
                // Fallback: find the main content area
                var mainContent = document.querySelector('.bslib-sidebar-layout > main, .bslib-sidebar-layout > .main');
                if (mainContent && mainContent.offsetWidth > 0) {
                    currentWidth = mainContent.offsetWidth;
                    currentHeight = mainContent.offsetHeight - 100; // Subtract for card header
                } else {
                    // Last resort: estimate from window
                    currentWidth = window.innerWidth - 350;
                    currentHeight = window.innerHeight - 200;
                }
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
    var debouncedReportSize = debounce(reportWindowSize, 250);

    // Update on window resize
    $(window).on('resize', debouncedReportSize);

    // Update when sidebar is toggled (bslib sidebar collapse)
    $(document).on('click', '.collapse-toggle', function () {
        // Delay to let the sidebar animation complete
        setTimeout(reportWindowSize, 350);
    });

    // Report on tab switches
    $(document).on('shown.bs.tab', function () {
        setTimeout(reportWindowSize, 50);
    });

    // Initial report after page load
    $(document).on('shiny:connected', function () {
        setTimeout(reportWindowSize, 100);
    });

    // Re-report when container content changes (uiOutput renders)
    // This ensures we measure after the container is actually rendered
    var observer = new MutationObserver(function (mutations) {
        var container = document.getElementById(targetId);
        if (container && container.offsetWidth > 0) {
            setTimeout(reportWindowSize, 50);
        }
    });

    // Start observing once document is ready
    $(document).ready(function () {
        observer.observe(document.body, { childList: true, subtree: true });
    });
}
