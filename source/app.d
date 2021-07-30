module notsharex.main;

static import std.process;
import std.stdio, std.path, std.file, std.exception, std.format,
std.algorithm, std.ascii, std.base64, std.conv, std.random, std.range, std.json, std.utf;
import core.stdc.stdlib : exit;

import painlessjson;
import asynchronous;

import notsharex.enums, notsharex.helpers, notsharex.config;

/// The apps required for the app to work
auto RequiredApps = [ "xfce4-screenshooter", "feh", "xdotool", "gio", "xsel", "espeak" ];

void main()
{
    if(!exists(expandTilde(Config.configFilePath))) {
        Config.writeConfig(new Config());
        exit(0);
    }

    //Read the config
    Config config = Config.readConfig();

    // Checks if the temporary directory exists
    if(!exists(config.temporaryDirectory)) {
        writefln("The temporary directory %s does not exist!", config.temporaryDirectory);
        exit(1);
    }

    // Change directory to the temporary dir
    chdir(config.temporaryDirectory);

    // Delete the images if they exist already
    if(exists(config.mainImagePath)) {
        remove(config.mainImagePath);
    }
    if(exists(config.staticPreviewPath)) {
        remove(config.staticPreviewPath);
    }

    // Check if our required apps are installed
    Helpers.checkForApps(RequiredApps);

    if(config.staticPreview) {
        // TODO TAKE AND DISPLAY STATIC PREVIEW
        assert(0);
    }

    string fullMainImagePath = buildNormalizedPath(config.temporaryDirectory, config.mainImagePath);

    // Take the screenshot
    const auto screenshotResult = Helpers.takeScreenshot(format("-r -s %s", fullMainImagePath));

    if(screenshotResult.status != 0) {
        writefln("Error occured while taking screenshot! Code: %s\nOutput: %s",
            screenshotResult.status, screenshotResult.output);
        exit(1);
    }

    // If the image does not exist, assume the user cancelled the operation
    if(!exists(fullMainImagePath)) {
        writefln("%s does not exist! Assume user cancelled operation! Message from screenshot: %s",
            fullMainImagePath, screenshotResult.output);
        exit(0);
    } else {
        writefln("Image saved at %s!", fullMainImagePath);
    }

    if(config.staticPreview) {
        // TODO KILL STATIC PREVIEW HERE
        assert(0);
    }

    string finalLink = "FAILED";
    switch(config.connectionType) {
        case ConnectionType.ftp:
        case ConnectionType.smb: {
            string mountFolder = config.connectionType == ConnectionType.smb ?
                format("smb-share:server=%s,share=%s", config.serverName, config.share) :
                format("ftp:host=%s", config.share);

            const auto mountResults = Helpers.mountFolder(format("%s/%s",
                config.server, config.share), config.credFile);

            if(mountResults.status != 0) {
                //writefln("Error occured during mounting! Code: %s\nOutput: %s",
                //    mountResults.status, mountResults.output);
                //exit(1);
            }

            try {
                //writefln("%s\n%s", format("/run/user/1000/gvfs/%s/", mountFolder), format("./%s", mountFolder));
                symlink(format("/run/user/1000/gvfs/%s/", mountFolder), format("./%s", mountFolder));
            } catch (FileException e) {
                //writefln("Error creating symlink!\nInfo: %s\nMessage:%s", e.info, e.msg);
                //exit(1);
            }

            //Generate random filename
            auto rndNums = rndGen().map!(a => cast(ubyte)a)().take(config.randomStringLength);
            auto result = appender!string();
            Base64.encode(rndNums, result);
            const string randomString = result.data.filter!isAlphaNum().to!string();

            copy(fullMainImagePath, format("%s%s/%s/%s.png",
                config.temporaryDirectory, mountFolder, config.pathToMoveTo, randomString));

            finalLink = format("%s/%s.png", config.link, randomString);

            break;
        }

        case ConnectionType.curl: {
            assert(0);
        }

        default: {
            writeln("Unknown connection type!");

            assert(0);
        }
    }

    Helpers.copyToClipboard(finalLink);
    Helpers.espeak(config.endMessage);
}
