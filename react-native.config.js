module.exports = {
  dependency: {
    platforms: {
      ios: {},
      android: {
        packageImportPath:
          'import com.reactnativeanimatedinput.RNAnimatedInputPackage;',
        packageInstance: 'new RNAnimatedInputPackage()',
      },
    },
  },
};
