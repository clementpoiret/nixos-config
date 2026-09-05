{ pkgs, lib, ... }:
with lib;
let
  categories = {
    archive = {
      applications = [ "org.gnome.FileRoller.desktop" ];
      mimeTypes = [
        "application/zip"
        "application/rar"
        "application/7z"
        "application/*tar"
      ];
    };
    text = {
      applications = [ "Helix.desktop" ];
      mimeTypes = [ "text/plain" ];
    };
    image = {
      applications = [ "pqiv.desktop" ];
      mimeTypes = [
        "image/avif"
        "image/bmp"
        "image/gif"
        "image/jpeg"
        "image/jpg"
        "image/png"
        "image/svg+xml"
        "image/tiff"
        "image/vnd.microsoft.icon"
        "image/webp"
      ];
    };
    audio = {
      applications = [ "mpv.desktop" ];
      mimeTypes = [
        "audio/aac"
        "audio/mpeg"
        "audio/ogg"
        "audio/opus"
        "audio/wav"
        "audio/webm"
        "audio/x-matroska"
      ];
    };
    video = {
      applications = [ "mpv.desktop" ];
      mimeTypes = [
        "video/mp2t"
        "video/mp4"
        "video/mpeg"
        "video/ogg"
        "video/webm"
        "video/x-flv"
        "video/x-matroska"
        "video/x-msvideo"
      ];
    };
    directory = {
      applications = [ "nautilus.desktop" ];
      mimeTypes = [ "inode/directory" ];
    };
    browser = {
      applications = [ "brave-browser.desktop" ];
      mimeTypes = [
        "text/html"
        "x-scheme-handler/about"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/unknown"
      ];
    };
    office = {
      applications = [ "libreoffice.desktop" ];
      mimeTypes = [
        "application/vnd.oasis.opendocument.text"
        "application/vnd.oasis.opendocument.spreadsheet"
        "application/vnd.oasis.opendocument.presentation"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        "application/msword"
        "application/vnd.ms-excel"
        "application/vnd.ms-powerpoint"
        "application/rtf"
      ];
    };
    pdf = {
      applications = [ "org.gnome.Evince.desktop" ];
      mimeTypes = [ "application/pdf" ];
    };
    terminal = {
      applications = [ "ghostty.desktop" ];
      mimeTypes = [ "terminal" ];
    };
  };

  associations = listToAttrs (
    concatLists (
      mapAttrsToList (
        _: category: map (type: nameValuePair type category.applications) category.mimeTypes
      ) categories
    )
  );
in
{
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.associations.added = associations;
  xdg.mimeApps.defaultApplications = associations;

  home.packages = with pkgs; [ junction ];

  home.sessionVariables = {
    # prevent wine from creating file associations
    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
  };
}
