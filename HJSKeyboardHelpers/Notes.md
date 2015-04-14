# 2015-04-14
As [per a post by Greg Clayton on 2015-04-01](https://devforums.apple.com/message/1120318#1120318) Xcode6.3 requires the following strings added to the "Other Swift flags" to a Swift framework:
    -Xfrontend -serialize-debugging-options

As of right now you can rotate a view while an adjustment is active and get some black space. Dismissing the keyboard will fix the problem, and I want to look in the future about handling this better.