const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { app, BaseWindow } = require("electron");

function fail(error) {
  console.error(error);
  app.exit(1);
}
process.on("uncaughtException", fail);
process.on("unhandledRejection", fail);
setTimeout(() => fail(new Error("Deezer did not finish startup")), 15000);

const archive = process.env.DEEZER_ARCHIVE;
const metadata = require(`${archive}/package.json`);
app.setName(metadata.name);
app.setVersion(metadata.version);
app.setAppPath(archive);
app.disableHardwareAcceleration();

let rendererReady = false;
let remoteReady = false;
function finish() {
  if (!rendererReady || !remoteReady) return;
  assert.equal(BaseWindow.getAllWindows().length, 1);
  fs.accessSync(path.join(path.dirname(archive), "assets/icon.png"));
  console.log(`Deezer ${app.getVersion()} rendered on Electron ${process.versions.electron}`);
  app.exit(0);
}

app.on("web-contents-created", (_, contents) => {
  contents.on("preload-error", (_, __, error) => fail(error));
  contents.on("render-process-gone", (_, details) => fail(details));
  // The real renderer and preloads run offline; only the remote website is replaced.
  const loadURL = contents.loadURL.bind(contents);
  contents.loadURL = (url, ...args) => loadURL(
    url.startsWith("https://") ? "data:text/html,<h1>Offline Deezer fixture</h1>" : url,
    ...args,
  );
  contents.on("did-finish-load", async () => {
    if (contents.getURL().startsWith("file://")) {
      assert.ok(await contents.executeJavaScript('document.querySelector("#root").children.length > 0'));
      rendererReady = true;
    } else if (contents.getURL().startsWith("data:")) {
      remoteReady = true;
    }
    finish();
  });
});

require(`${archive}/${metadata.main}`);
