import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.tagtag.playgroundblitz',
  appName: 'Tag Tag',
  webDir: 'dist',
  bundledWebRuntime: false,
  android: {
    backgroundColor: '#36d6ff',
  },
};

export default config;
