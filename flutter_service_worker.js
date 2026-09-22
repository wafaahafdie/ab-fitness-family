'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "729aa04c451ab79e263a80cef66af40f",
"assets/AssetManifest.bin.json": "718d8ed6dea2cb2f1c45d817af87c255",
"assets/AssetManifest.json": "2b93502edbedc003415ed372b9791d97",
"assets/assets/images/aa.png": "08349bac3281409e681226f4c6c8a86a",
"assets/assets/images/ab.png": "8821369d3de21395bb4eabb1750aef52",
"assets/assets/images/ac.png": "a1fd53240aec33cef73015b01399694b",
"assets/assets/images/acc.png": "f36fffce980aaf887606360f0619de4a",
"assets/assets/images/acp.png": "f36fffce980aaf887606360f0619de4a",
"assets/assets/images/ader.png": "9a43886184df35d55d9fad414f02ff03",
"assets/assets/images/adr.png": "b76a8985a84f87a01df2ea24ecd44053",
"assets/assets/images/aj.png": "20c1338a712cea18777b5828b9930266",
"assets/assets/images/alg.png": "bc0a1a27469705ccd7e397b49c148360",
"assets/assets/images/am.png": "d7b94a1b56813f5ed7026a49950ef6e5",
"assets/assets/images/an.png": "97bd5613b2fdc3d4d39b5c4ab83eef9d",
"assets/assets/images/att.png": "ed0c9646c378073cf7712bf63b9cb8e8",
"assets/assets/images/attt.png": "ed0c9646c378073cf7712bf63b9cb8e8",
"assets/assets/images/az.png": "9935fd4a0bb5a75ed81ee0dfb68590ea",
"assets/assets/images/br.png": "d187a88d453221ba1b17db05ee61f668",
"assets/assets/images/ca.png": "480bf577120a64170aa559739a102848",
"assets/assets/images/cal.png": "f7e7623c17eeda4d7dfa66d52702d299",
"assets/assets/images/cam.png": "de8379a6e5dd8ce8eda3f24939624f25",
"assets/assets/images/cat.png": "1f02fb240d0646aa1974523d1bd466d4",
"assets/assets/images/cc.png": "aed6921b70b96e4a88fc4d0a890249ab",
"assets/assets/images/cetr.png": "50ad901961218be4c4a358c1b20369b7",
"assets/assets/images/ch.png": "69ef3922eb11f1666a9e962a370decad",
"assets/assets/images/cha.png": "cbb61dfe4da39944481e98d22d0cb548",
"assets/assets/images/cv.png": "b51b2ef69354075755b530ab7cd1ac36",
"assets/assets/images/cvs.png": "b86a0d3c0543848fcf6cc9708d79d6b1",
"assets/assets/images/dd.png": "1df2a857d5f9793deb89ed58ec5d1067",
"assets/assets/images/des.png": "f3e14e20c1e472a49750f2c7edb89f56",
"assets/assets/images/dip.png": "e0ba1d1f20cac5d49c0d7b5eb5765a90",
"assets/assets/images/doc.png": "1eab75cb45c5d3bcc2dfc0b7571fbaf2",
"assets/assets/images/ee%2520(1).png": "b46876614ee3b9d7ed35ecda7b75b735",
"assets/assets/images/ee%2520(2).png": "6c79a1f724b292b1948f917158cfad60",
"assets/assets/images/ee%2520(3).png": "f454c29bbde76f04a2ed147899c1a411",
"assets/assets/images/ee%2520(4).png": "f7c56808cfb7fb7aa6d86bf10e937bf6",
"assets/assets/images/ee%2520(5).png": "780ecb3c5992137a8fa71422185f8cfa",
"assets/assets/images/em.png": "4cd0ef1f9449f2d7d24d4a7ea54b9d79",
"assets/assets/images/env.png": "5ea57c5a796d0ac2a403674b6d29c6a7",
"assets/assets/images/es.png": "6b279d7b041b370d9ea973b0a11e43cb",
"assets/assets/images/fb.png": "550f1ce1f248352264bc80cea2a297e2",
"assets/assets/images/fbl.png": "20e88b46d9d930f41c0ca39cc3396004",
"assets/assets/images/fem.png": "049a938a37e57b0b7b88063b56704876",
"assets/assets/images/ff.png": "cb8d64ff721fee60393aee70a5ca8213",
"assets/assets/images/fm.png": "e11da74e410775f7e8fbade215db42a8",
"assets/assets/images/gre.png": "bb51662c6b886088196a150febbdd013",
"assets/assets/images/hom.png": "3f26f1ebc6eb506e404c7cd44d1e3a1b",
"assets/assets/images/hr.png": "b982def6a7085108b9fc9d2892ade8b9",
"assets/assets/images/icon.png": "48883225dc2e44d8fa560cd612cc1e5e",
"assets/assets/images/ima.png": "1cb68f434a1e14adf9125d918e70845c",
"assets/assets/images/imag.png": "ed841864dd81d8ab43d8bcfa9d08f902",
"assets/assets/images/imp.png": "20eebef8d9b7a59bbab74f51d88aa0c2",
"assets/assets/images/king.png": "0b28da894ab7564061a7fa193bdbf98c",
"assets/assets/images/lg.png": "bd1997e71f1965c240cbe945ea52f4fa",
"assets/assets/images/logo.png": "109f5754d19c1a3e9b25eabda378cc4a",
"assets/assets/images/ma.png": "eabbbe723e7ab0817a8de1c7118f8cec",
"assets/assets/images/mail.png": "a120986e680bcb9f4f3f5243ca4bd98a",
"assets/assets/images/mem.png": "86193b210d347af8e34ac11a191c3bea",
"assets/assets/images/menu.png": "eb8dedac0f9daeb15ede1c073987d41c",
"assets/assets/images/modif.png": "766f1fb38104c3e276f62feb0834aa76",
"assets/assets/images/not.png": "259898089830e8136e0c110da3ad0740",
"assets/assets/images/notif.png": "0108c81604ca9df2bdac7b0019ffeffe",
"assets/assets/images/oo.png": "482d20b5125a57fae5abba3861e1af64",
"assets/assets/images/par.png": "85bd3261e47545f12843b9d0565503a4",
"assets/assets/images/part.png": "468cf38b98ac4040bd23eb8a202b57d0",
"assets/assets/images/pl.png": "67d76069d45b8d40c1f01128c3f6e8f1",
"assets/assets/images/plus.png": "aa157a3be15df2785d89ddabc9aa5f42",
"assets/assets/images/po.png": "cdf60ec1e8d8c9baf07b556e5b3553ed",
"assets/assets/images/poin.png": "67c741429f93eb2fbd903b6bef8e5cc4",
"assets/assets/images/pp.png": "dcb846f6d249f6306bba934bdc068507",
"assets/assets/images/profilpat.jpg": "475625351efca0ab04b055ba21136d48",
"assets/assets/images/qst.png": "ae7846726275a98788a5bbbd8ff6ee47",
"assets/assets/images/qste.png": "0094cc4e4b310c0362777a66ae0b4b4c",
"assets/assets/images/rbl.png": "d187a88d453221ba1b17db05ee61f668",
"assets/assets/images/rec.png": "6b5afccc70ec3ca6d50b7a8741bdcdfb",
"assets/assets/images/ref.png": "690a406d0a7259d5dd03189b705bf9dd",
"assets/assets/images/refu.png": "690a406d0a7259d5dd03189b705bf9dd",
"assets/assets/images/rgr.png": "4fe068f05cbcd9226e1012992f9434cf",
"assets/assets/images/rr.png": "a3a7816100acd642fb55f1f247d9a0e3",
"assets/assets/images/sp.png": "152488c4ef2b0ec986940a1fb5360a03",
"assets/assets/images/ss.png": "a53b86d74cedbf8407afbd3619315c50",
"assets/assets/images/sui.png": "2fb8a7ebc8bb7f6b98c73abbcc8e20f1",
"assets/assets/images/sv.png": "f16f8a74fb1aea5ab428247171e0f8f5",
"assets/assets/images/tel.png": "2f1ffdf391dc4cc176faf739c99af114",
"assets/assets/images/telecharger.png": "a638edd2ca8889d691fc158323898f33",
"assets/assets/images/tl.png": "0dc76b973c20aaf23ed824cf8cb620aa",
"assets/assets/images/tlb.png": "4792230d65e1b0fe23be7dfb570a1452",
"assets/assets/images/tlbleu.png": "85e6b11bf5ee4ca63d3755a318a68200",
"assets/assets/images/tt.png": "bef1177cfe579d5f408a80368f496f2d",
"assets/assets/images/ttt.png": "b413f13becf852a64640a08a6c0247c3",
"assets/assets/images/us.png": "b46876614ee3b9d7ed35ecda7b75b735",
"assets/assets/images/user.png": "46e3a8c1062fec6e5ce8241ac67f4dc0",
"assets/assets/images/util.png": "bcbe67f78d0cb386e394f455a0fa5297",
"assets/assets/images/uu.png": "7a62bd76ec4e6a71de5cfc275fdafd6a",
"assets/assets/images/ved.png": "4ad64f8195d0e24a6757105b5ed4eddb",
"assets/assets/images/vid.png": "cfa8f7719ac23b75bdf456740bc4b380",
"assets/assets/images/voir.png": "6f2f96540e5b8a6ccbaa85e7637410f9",
"assets/assets/images/vv.png": "686023d70d7ae5afb6340b080f81e1a7",
"assets/assets/images/xx.png": "1a3ad79386271a4fa2b6546be0c196a3",
"assets/assets/images/yeux.png": "698aa1bed9c9f9f70565901e7d2442dc",
"assets/assets/sounds/notification.mp3": "056472d367276f3478b3f84f3c466ebf",
"assets/FontManifest.json": "866b9b20ab0e8c30ffe220d2a2d66abe",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"assets/NOTICES": "f565b5479bc3599c0ac53f7ade6f585c",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/packages/syncfusion_flutter_pdfviewer/assets/fonts/RobotoMono-Regular.ttf": "5b04fdfec4c8c36e8ca574e40b7148bb",
"assets/packages/syncfusion_flutter_pdfviewer/assets/highlight.png": "7384946432b51b56b0990dca1a735169",
"assets/packages/syncfusion_flutter_pdfviewer/assets/squiggly.png": "c9602bfd4aa99590ca66ce212099885f",
"assets/packages/syncfusion_flutter_pdfviewer/assets/strikethrough.png": "cb39da11cd936bd01d1c5a911e429799",
"assets/packages/syncfusion_flutter_pdfviewer/assets/underline.png": "c94a4441e753e4744e2857f0c4359bf0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"flutter_bootstrap.js": "0ad831fc49bf139a6cbfce953fd2ff6e",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "216e1ec60d98cecc970fc1e40b257916",
"/": "216e1ec60d98cecc970fc1e40b257916",
"main.dart.js": "a13fa40575679e7a6b982090ad3111ea",
"manifest.json": "4fc5e31301aa2cead8d465bf18991856",
"version.json": "7d782953922f6d6d7aa728475c3b1684"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
