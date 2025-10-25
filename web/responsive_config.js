// =============================================================================
// RESPONSIVE WEB CONFIGURATION
// =============================================================================
// This file provides responsive configuration for the web app
// to ensure proper functionality on local network access

(function() {
  'use strict';

  // Local network configuration
  const LOCAL_NETWORK_CONFIG = {
    baseUrl: 'http://10.120.4.230:8082',
    apiUrl: 'http://10.120.4.230:8082/api',
    websocketUrl: 'ws://10.120.4.230:8082',
    fallbackUrls: [
      'http://localhost:8082',
      'http://127.0.0.1:8082'
    ]
  };

  // Responsive breakpoints
  const BREAKPOINTS = {
    mobile: 600,
    tablet: 900,
    desktop: 1200
  };

  // Get current screen size
  function getScreenSize() {
    const width = window.innerWidth;
    if (width < BREAKPOINTS.mobile) return 'mobile';
    if (width < BREAKPOINTS.tablet) return 'tablet';
    return 'desktop';
  }

  // Responsive utilities
  const ResponsiveUtils = {
    isMobile: () => getScreenSize() === 'mobile',
    isTablet: () => getScreenSize() === 'tablet',
    isDesktop: () => getScreenSize() === 'desktop',
    
    getResponsiveValue: (mobile, tablet, desktop) => {
      const size = getScreenSize();
      switch (size) {
        case 'mobile': return mobile;
        case 'tablet': return tablet;
        case 'desktop': return desktop;
        default: return desktop;
      }
    },

    // Responsive font sizes
    getFontSize: (baseSize) => {
      const size = getScreenSize();
      const multipliers = {
        mobile: 0.9,
        tablet: 1.0,
        desktop: 1.1
      };
      return baseSize * multipliers[size];
    },

    // Responsive spacing
    getSpacing: () => {
      return ResponsiveUtils.getResponsiveValue(12, 16, 24);
    },

    // Responsive padding
    getPadding: () => {
      return ResponsiveUtils.getResponsiveValue(16, 24, 32);
    }
  };

  // Network connectivity check
  function checkNetworkConnectivity() {
    const testUrl = LOCAL_NETWORK_CONFIG.baseUrl + '/api/health';
    
    return fetch(testUrl, {
      method: 'GET',
      mode: 'cors',
      headers: {
        'ngrok-skip-browser-warning': 'true'
      }
    })
    .then(response => response.ok)
    .catch(() => false);
  }

  // Initialize responsive features
  function initializeResponsiveFeatures() {
    // Add responsive CSS classes
    function updateResponsiveClasses() {
      const size = getScreenSize();
      document.body.className = document.body.className.replace(/screen-\w+/g, '');
      document.body.classList.add(`screen-${size}`);
    }

    // Update on resize
    window.addEventListener('resize', updateResponsiveClasses);
    updateResponsiveClasses();

    // Add responsive CSS
    const style = document.createElement('style');
    style.textContent = `
      .screen-mobile {
        --responsive-padding: 16px;
        --responsive-spacing: 12px;
        --responsive-font-size: 0.9em;
      }
      
      .screen-tablet {
        --responsive-padding: 24px;
        --responsive-spacing: 16px;
        --responsive-font-size: 1.0em;
      }
      
      .screen-desktop {
        --responsive-padding: 32px;
        --responsive-spacing: 24px;
        --responsive-font-size: 1.1em;
      }

      /* Responsive container */
      .responsive-container {
        max-width: 100%;
        margin: 0 auto;
        padding: var(--responsive-padding);
      }

      .screen-mobile .responsive-container {
        max-width: 100%;
      }

      .screen-tablet .responsive-container {
        max-width: 768px;
      }

      .screen-desktop .responsive-container {
        max-width: 1200px;
      }

      /* Responsive grid */
      .responsive-grid {
        display: grid;
        gap: var(--responsive-spacing);
      }

      .screen-mobile .responsive-grid {
        grid-template-columns: 1fr;
      }

      .screen-tablet .responsive-grid {
        grid-template-columns: repeat(2, 1fr);
      }

      .screen-desktop .responsive-grid {
        grid-template-columns: repeat(3, 1fr);
      }

      /* Responsive text */
      .responsive-text {
        font-size: var(--responsive-font-size);
      }

      /* Responsive buttons */
      .responsive-button {
        padding: calc(var(--responsive-padding) / 2) var(--responsive-padding);
        font-size: var(--responsive-font-size);
        min-height: ResponsiveUtils.getResponsiveValue(48, 52, 56) + 'px';
      }

      /* Responsive modals */
      .responsive-modal {
        max-width: ResponsiveUtils.getResponsiveValue('100%', '600px', '700px');
        margin: 0 auto;
      }

      /* Touch-friendly on mobile */
      .screen-mobile .touch-target {
        min-height: 44px;
        min-width: 44px;
      }

      /* Hover effects only on desktop */
      .screen-desktop .hover-effect:hover {
        transform: translateY(-2px);
        transition: transform 0.2s ease;
      }
    `;
    document.head.appendChild(style);
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeResponsiveFeatures);
  } else {
    initializeResponsiveFeatures();
  }

  // Export utilities to global scope
  window.ResponsiveUtils = ResponsiveUtils;
  window.LOCAL_NETWORK_CONFIG = LOCAL_NETWORK_CONFIG;
  window.checkNetworkConnectivity = checkNetworkConnectivity;

  // Log initialization
  console.log('Responsive web configuration initialized');
  console.log('Screen size:', getScreenSize());
  console.log('Local network config:', LOCAL_NETWORK_CONFIG);

})();
