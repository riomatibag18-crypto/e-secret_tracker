const kMapboxAccessTokenFromEnv = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

String get effectiveMapboxAccessToken => kMapboxAccessTokenFromEnv;
