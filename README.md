# BuildAPIAccess 3.0.0

An Objective-C (Mac OS X / iOS / tvOS) class wrapper for [Electric Imp’s impCentral API](https://electricimp.com/docs/tools/impcentralapi/). It is called Build API Access for historical reasons.

BuildAPIAccess requires the (included) class Connexion, a simple convenience class for bundling an [NSURLSession](https://developer.apple.com/library/prerelease/mac/documentation/Foundation/Reference/NSURLSession_class/index.html) instance and associated impCentral API connection data. NSURLSession is Apple’s preferred mechanism.

### impCentral API Authorization

Making use of the impCentral API requires an Electric Imp account. You will need your account username and password to authorize calls to the API.

Each *BuildAPIAccess* instance does not maintain a permanent record of the selected account; this is the task of the host application. *BuildAPIAccess* does require this information, so methods are provided to pass an account’s username and password into *BuildAPIAccess* instances.

## Licence and Copyright

BuildAPIAccess is &copy; Tony Smith, 2015-2017 and is offered under the terms of the MIT licence.

The impCentral API is &copy; Electric Imp, 2017.

## HTTP User Agent

From version 2.0.1, BuildAPIAccess issues HTTPS requests with a custom user agent string of the following form:

```
BuildAPIAcces/<VERSION> <HOST_APP_NAME>/<VERSION> (macOS <VERSION>)
```
