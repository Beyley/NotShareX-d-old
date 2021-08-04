///
module notsharex.helpers;

static import std.process;
import std.stdio, std.path, std.file, std.exception, std.format,
std.algorithm, std.ascii, std.base64, std.conv, std.random, std.range, std.json, std.utf;
import core.stdc.stdlib : exit;

import notsharex.config;

import painlessjson;

/// Various helper functions
class Helpers {
    /// Checks if an array of apps are installed
    static void checkForApps(string[] apps) {
        foreach(app; apps) { 
            checkForApp(app);
        }
    }
    
    /// Checks if an app is installed    
    static void checkForApp(string app) {
        if(std.process.executeShell(format("command -v %s", app)).output == null) {
            writefln("You do not have %s installed!", app);
            exit(1);
        }
    }
    
    /// Takes a screenshot with the defined cli options
    static auto takeScreenshot(string cliOptions) {
        return std.process.executeShell(format("xfce4-screenshooter %s", cliOptions));
    }
    
    /// Mounts a folder with the specified creds
    static auto mountFolder(string folderToMount, string creds) {
        return std.process.executeShell(format("gio mount %s < %s", folderToMount, creds));
    }
    
    /// Speaks a message using espeak
    static void espeak(string text) {
        std.process.executeShell(format("espeak \"%s\"", text));
    }
    
    /// Copies some text to the clipboard
    static void copyToClipboard(string text) {
        std.process.executeShell(format("echo \"%s\" | tr -d '\n' | xsel -b > /dev/null", text));
    }

    static void takeStaticImage(Config config) {
        std.process.executeShell(format("xfce4-screenshooter -f -s %s", buildPath(expandTilde(config.temporaryDirectory), config.staticPreviewPath)));
    }

    /// Makes a CURL request
    static string curl(Config config) {
        return std.process.executeShell(format("curl -s -F \"reqtype=fileupload\" -F \"%s=%s\" -F \"%s=@%s%s\" %s", config.uploadCredsName, config.userHash, config.uploadFileName, config.temporaryDirectory, config.mainImagePath, config.server)).output;
    }

    /// Reads an entire file into a string
    static string readWholeFile(string path) {
        return cast(string)read(expandTilde(path).byChar);
    }
}
