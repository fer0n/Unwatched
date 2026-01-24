console.log("Unwatched popup opened", browser);

const textElement = document.getElementById("popup-text");
if (textElement) {
  textElement.innerText = browser.i18n.getMessage("popup_description");
}
