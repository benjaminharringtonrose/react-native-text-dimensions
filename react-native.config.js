module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath:
          "import com.benjaminharringtonrose.RNTextDimensionsPackage;",
        packageInstance: "new RNTextDimensionsPackage()",
      },
      ios: {
        podspecPath: "RNTextDimensions.podspec",
      },
    },
  },
};
