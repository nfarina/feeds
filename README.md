![Example Screenshot](Assets/Screenshot.png)

Overview
========

Feeds lives in your Mac's menu bar and lets you quickly view the content of new posts on your favorite web services without ever opening a browser window.

For more information, see the [Official Website](http://www.feedsapp.com).


Adding New Account Types
------------------------

To add a new service to Feeds, you simply write an `Account` subclass. We're still working on documentation for how to write these classes, but you can examing the existing ones to get a sense for it.

Note regarding **Github two-factor authentication**

2FA isn't yet supported, in the mean time you can create an app token in: [Settings > Tokens](https://github.com/settings/tokens), and provide the token as your password.


Migrating Your Old Accounts
---------------------------

If you originally downloaded Feeds from the Mac App Store, your existing preferences file (with all the accounts you added) will have been stored in the Mac App Sandbox. If you want to reuse your old preferences file, you can find it here:

    ~/Library/Containers/com.feedsapp.Feeds/Data/Library/Preferences/com.feedsapp.Feeds.plist

And simply copy it to here:

    ~/Library/Preferences/com.feedsapp.Feeds.plist
