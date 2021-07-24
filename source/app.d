import std.stdio, std.path, std.file, std.exception, std.process, std.format,
std.algorithm, std.ascii, std.base64, std.conv, std.random, std.range, std.json, std.utf;
import core.stdc.stdlib : exit;
import painlessjson;

/// The connection type for the server
enum ConnectionType {
    /// Samba
    smb,
    /// File Transfer Protocol
    ftp,
    /// idk what it stands for
    curl
}

/// A struct that defines the configuration
class Config {
    /// The path to the configuration file
    const static string configFilePath = "~/.config/notsharex/config.json";

    /// The main path that stores the image you take
    string mainImagePath    = "temp.png";
    /// The path used to store the static preview
    string staticPreviewPath = "static.png";

    /// Whether to show a static preview while selecting the area
    bool staticPreview = false;
    /// The connection type to use when interacting with the server
    ConnectionType connectionType = ConnectionType.smb;
    /// The directory to store all of the temporary files, etc. the image taken / the static preview
    string temporaryDirectory = "/tmp/";

    /// The server address
    string server = "smb://192.168.0.201";
    /// The server name?
    string serverName = "192.168.0.201";
    /// The share to access
    string share = "root";
    /// The link for the final thing
    string link = "https://i.beyleyisnot.moe";
    /// The path in the share to move to
    string pathToMoveTo = "home/beyley/image-subdomain";

    /// The length of the random filename
    int randomStringLength = 5;
    /// The message to say at the end
    string endMessage = "pen 15";

    /// The credentials file
    string credFile = "~/.config/notsharex/.creds";

    /// Reads the config
    static Config readConfig() {
        Config tempConfig = new Config();

        string fullFile = cast(string)read(expandTilde(configFilePath).byChar);

        return fromJSON!Config(parseJSON(fullFile));
    }

    /// Writes the current config to a file
    static void writeConfig(Config config) {
        std.file.write(expandTilde(Config.configFilePath), config.toJSON.toString);
    }
}

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
    Helpers.checkForApps([ "xfce4-screenshooter", "feh", "xdotool", "gio", "xsel", "espeak" ]);

    if(config.staticPreview) {
        // TODO IMPLEMENT STATIC PREVIEW
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

        default: assert(0);
    }

    Helpers.copyToClipboard(finalLink);
    Helpers.espeak(config.endMessage);
}
