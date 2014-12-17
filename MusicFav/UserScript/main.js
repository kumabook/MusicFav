;
window.webkit.messageHandlers.MusicFav.postMessage(
  JSON.stringify(new playlistify.Scraper().extractPlaylist(document))
);
