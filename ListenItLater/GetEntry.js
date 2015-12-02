var GetEntry = function() {};

GetEntry.prototype = {
  run: function(arguments) {
    arguments.completionFunction({"url": document.baseURI, "title": document.title});
  },

  finalize: function(arguments) {
    document.body.style.backgroundColor = arguments["bgColor"];
  }
};

var ExtensionPreprocessingJS = new GetEntry();