module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath:
          "import com.github.amarcruz.rntextsize.RNTextDimensionsPackage;",
        packageInstance: "new RNTextDimensionsPackage()",
      },
      ios: {
        podspecPath: "ios/RNTextDimensions.podspec",
      },
    },
  },
};
