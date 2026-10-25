// Pingulinux: Social-Media und normales YouTube sperren.
// YouTube Kids (youtubekids.com) bleibt erreichbar.
function FindProxyForURL(url, host) {
  host = host.toLowerCase();
  var blocked = [
    "facebook.com", "instagram.com", "tiktok.com", "snapchat.com",
    "twitter.com", "x.com", "reddit.com", "discord.com", "threads.net",
    "youtube.com", "youtu.be"
  ];
  for (var i = 0; i < blocked.length; i++) {
    if (host === blocked[i] || dnsDomainIs(host, "." + blocked[i])) {
      return "PROXY 127.0.0.1:9";
    }
  }
  return "DIRECT";
}
