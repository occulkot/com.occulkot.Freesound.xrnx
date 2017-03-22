# Summary

[Renoise](http://renoise.com) tool for accessing http://freesound.org library.

# Usage instructions

1. Follow the instructions [here](http://www.freesound.org/docs/api/authentication.html#token-authentication) to get a Freesound API key.
1. Clone this repository.
1. Open `credentials.lua`. Edit the line with `YOUR_API_KEY` with your actual API key. For instance, if your API key were `123abc`, that line would read:
```
credentials.token = "123abc"
```
1. In your file browser, drag the entire `com.occulkot.Freesound.xrnx` directory and drop it on top of the icon of your Renoise application.
1. Access the tool in Renoise via `Tools > Freesound > Browse samples`, and update settings via `Tools > Freesound > Settings`.
