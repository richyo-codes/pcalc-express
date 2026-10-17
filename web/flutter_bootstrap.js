{{flutter_js}}
{{flutter_build_config}}

async function startCalculator() {
  if ('serviceWorker' in navigator) {
    try {
      // Start loading assets after activation so the first visit can cache them.
      await Promise.race([
        navigator.serviceWorker.register('service_worker.js')
          .then(() => navigator.serviceWorker.ready)
          .then(() => {
            if (navigator.serviceWorker.controller) return;
            return new Promise((resolve) => navigator.serviceWorker.addEventListener(
              'controllerchange', resolve, { once: true },
            ));
          }),
        new Promise((resolve) => setTimeout(resolve, 3000)),
      ]);
    } catch (_) {
      // Calculator startup remains available when service workers are blocked.
    }
  }
  _flutter.loader.load({ config: { canvasKitBaseUrl: 'canvaskit/' } });
}

startCalculator();
