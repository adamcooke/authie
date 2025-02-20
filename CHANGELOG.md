# Changelog

## [5.0.0](https://github.com/adamcooke/authie/compare/v4.1.6...v5.0.0) (2025-02-20)


### ⚠ BREAKING CHANGES

* Authie no longer supports Rails <= 7.0. Official support for Rails 7.0 ended over a year ago, we don't need to continue supporting it in Authie 5.0 and higher. Rails 7.0 can continue to use the 4.x releases.
* If a coder was set using `config.active_record.default_column_serializer` then it will no longer be respected. You will need to set `Authie.config.serialize_coder` to override the coder for Authie sessions.

### Features

* allow data serialization encoder to be defined using `Authie.config.serialize_coder`. ([588b5e7](https://github.com/adamcooke/authie/commit/588b5e7b0cc0e03fa3282b4fc088a18b866b0932))


### Miscellaneous Chores

* remove support for Rails 7.0 ([1b09a80](https://github.com/adamcooke/authie/commit/1b09a80efaf1525a4079abf793bdfb93d9246917))


### Tests

* use the &gt;= 7.0 migration context ([7daabf1](https://github.com/adamcooke/authie/commit/7daabf1aff3cf06fec544f6b6e6f8fb9f7f55f6d))

## [4.1.6](https://github.com/adamcooke/authie/compare/v4.1.5...v4.1.6) (2025-02-04)


### Miscellaneous Chores

* update action dependencies for release ([c070a1e](https://github.com/adamcooke/authie/commit/c070a1e3a197c04dff8631839f4430596e8ab581))

## [4.1.5](https://github.com/adamcooke/authie/compare/v4.1.4...v4.1.5) (2025-02-04)


### Miscellaneous Chores

* add additional changelog sections to release please ([e6c763d](https://github.com/adamcooke/authie/commit/e6c763d1acb4f33ae2a988952329c815d5bb6d0c))
* exclude 3.1/8.0 and 3.4/7.0 ([8456d8d](https://github.com/adamcooke/authie/commit/8456d8ded1accbda3d8bad838ec20bf09af42eb2))
* unpin sqlite ([74043d6](https://github.com/adamcooke/authie/commit/74043d68a8d8aa6ce397255c84f7592be03b27a0))
* update ci to include rails 8 and ruby 3.3/3.4 ([1326f9e](https://github.com/adamcooke/authie/commit/1326f9e49b9edf050a24046b732907f56d1a893a))


### Tests

* require 'logger' in tests ([e1f55d3](https://github.com/adamcooke/authie/commit/e1f55d31315137b87ed2473deeb307ff1acee963))

## [4.1.4](https://github.com/adamcooke/authie/compare/v4.1.3...v4.1.4) (2024-01-29)


### Bug Fixes

* fixes RackController session lookup ([#40](https://github.com/adamcooke/authie/issues/40)) ([89395b4](https://github.com/adamcooke/authie/commit/89395b4e23d33193b3ca4a30c3ed0bb19fd533f3))

## [4.1.3](https://github.com/adamcooke/authie/compare/v4.1.2...v4.1.3) (2023-11-02)


### Bug Fixes

* fix dependency constraints ([0268de8](https://github.com/adamcooke/authie/commit/0268de87c02acd3ab0a1c01b70ed8153cb11d075))

## [4.1.2](https://github.com/adamcooke/authie/compare/v4.1.1...v4.1.2) (2023-11-02)


### Bug Fixes

* don't provide Schema::Migration in Rails &gt;= 7.0 ([57f2857](https://github.com/adamcooke/authie/commit/57f2857ba9c38bbc2078ca45be6ca13c55ed9373))
* specify type of object for serialise data attribute ([48263f8](https://github.com/adamcooke/authie/commit/48263f84bae4a3e00ca67c878019503e83b09e34))

## [4.1.1](https://github.com/adamcooke/authie/compare/v4.1.0...v4.1.1) (2023-06-27)


### Bug Fixes

* expose Config#lookup_ip_country_backend ([8473337](https://github.com/adamcooke/authie/commit/8473337fce552cb4d1ae5788e304347b2266b3d9))

## [4.1.0](https://github.com/adamcooke/authie/compare/v4.0.0...v4.1.0) (2023-06-27)


### Features

* support for storing ip address countries ([90b2394](https://github.com/adamcooke/authie/commit/90b2394c7080feb9b355de0dec4e46e6683c64a2))

## [4.0.0](https://github.com/adamcooke/authie/compare/v3.4.0...v4.0.0) (2023-05-02)


### Features

* ability to have expiry times increased on session activity ([a67dbbe](https://github.com/adamcooke/authie/commit/a67dbbed0d7e6d322e2516dc296b25d339c51a6a))
* ability to pass session options to ControllerDelegate#create_auth_session ([38922f4](https://github.com/adamcooke/authie/commit/38922f4ac941dcebba5043dbf6ec8682dc213102))
* ability to skip session touching within a request ([593eacf](https://github.com/adamcooke/authie/commit/593eacf83c4d2fd5ce50f0703c88914a4971a9b7))
* active support notifications ([ce0c895](https://github.com/adamcooke/authie/commit/ce0c89574208091b0165c8133e4dd274f65aae4f))
* add boolean for storing two factor skip state ([ec834df](https://github.com/adamcooke/authie/commit/ec834dff52fb54d07f718e1e5fb5669ecde300d7))
* add notification on session invalidation ([cf9af97](https://github.com/adamcooke/authie/commit/cf9af97d5d76bf8539a54256a5975e7722e0cb9d))
* add session to validity exceptions ([9e23f19](https://github.com/adamcooke/authie/commit/9e23f19e4cf4c9ba25941f1104e4ee3d8e2580e7))
* allow persistent sessions to be created ([9ed6b6d](https://github.com/adamcooke/authie/commit/9ed6b6d759bc2ee7e68180a2e1bd52e64e8a7e43))
* customisable token lengths ([41431a6](https://github.com/adamcooke/authie/commit/41431a66cf943f5f70abe1fa6dc059271b5f46cd))
* separate touching & validating auth sessions ([e688762](https://github.com/adamcooke/authie/commit/e688762662215c823d9fe8bbf2cc6e1cef815b24))
* support for resetting a token to a new value ([ed6f138](https://github.com/adamcooke/authie/commit/ed6f1381a4a69913cede483bd3c947320ac3b543))


### Bug Fixes

* do not invalidate inactive sessions when invalidating others ([56a659b](https://github.com/adamcooke/authie/commit/56a659bec5438966fec24c3b8b48da5c68c7d5c9))
* don't inspect sessions when invalidating others ([5a81581](https://github.com/adamcooke/authie/commit/5a81581d66a8e56200bd67726f27f76a265593e4))
* don't override skip_two_factor whenever calling #mark_as_two_factored ([7e5c8a0](https://github.com/adamcooke/authie/commit/7e5c8a032c1383574f9c1f96d7f7007ff791130a))
* maintain Authie::Session.cleanup ([5776421](https://github.com/adamcooke/authie/commit/5776421bb4d2f8f4cbe71bae927b3a132d877b58))
* only add helper methods if the controller supports them ([bbeca3b](https://github.com/adamcooke/authie/commit/bbeca3b055b7b4ea0934d82e8ee4a3356dfe62de)), closes [#24](https://github.com/adamcooke/authie/issues/24)
* require all of active record for the session model ([c042e34](https://github.com/adamcooke/authie/commit/c042e34f9002feaac9448de0cd9d4e58fbaec029))
