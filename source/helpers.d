module notsharex.helpers;

import std.stdio, std.path, std.file, std.exception, std.process, std.format,
std.algorithm, std.ascii, std.base64, std.conv, std.random, std.range, std.json, std.utf;
import core.stdc.stdlib : exit;
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
        if(executeShell(format("command -v %s", app)).output == null) {
            writefln("You do not have %s installed!", app);
            exit(1);
        }
    }
    
    /// Takes a screenshot with the defined cli options
    static auto takeScreenshot(string cliOptions) {
        return executeShell(format("xfce4-screenshooter %s", cliOptions));
    }
    
    /// Mounts a folder with the specified creds
    static auto mountFolder(string folderToMount, string creds) {
        return executeShell(format("gio mount %s < %s", folderToMount, creds));
    }
    
    /// Speaks a message using espeak
    static void espeak(string text) {
        executeShell(format("espeak \"%s\"", text));
    }
    
    /// Copies some text to the clipboard
    static void copyToClipboard(string text) {
        executeShell(format("echo \"%s\" | xsel -b > /dev/null", text));
                //exit(0);
    }
}
