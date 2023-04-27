module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath:
          "import com.rntextdimensions.RNTextDimensionsPackage;",
        packageInstance: "new RNTextDimensionsPackage()",
      },
      ios: {
        podspecPath: "RNTextDimensions.podspec",
      },
    },
  },
};
