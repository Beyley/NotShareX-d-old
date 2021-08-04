///
module notsharex.app;

import std.stdio, std.path, std.file, std.exception, std.format,
std.algorithm, std.ascii, std.base64, std.conv, std.random, std.range, 
std.json, std.utf, std.string, std.getopt;
import core.stdc.stdlib : exit;

import glui;
import raylib;

import notsharex.enums, notsharex.helpers, notsharex.config;

/// The apps required for the app to work
auto RequiredApps = [ "xfce4-screenshooter", "feh", "xdotool", "gio", "xsel", "espeak" ];

/// Whether to run the configuration wizard
bool runConfig = false;

/// entry point for dlangui based application
void main(string[] args)
{
    std.getopt.getopt(args,
        "config", &runConfig
    );

    if(!exists(expandTilde(Config.configFilePath))) {
        mkdir(expandTilde(Config.configFilePath));
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


    if(runConfig) {
        configWizard(config);
    } else {
        screenshot(config);
    }
}

/// Runs the configuration wizard
void configWizard(Config config) {
    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(1400, 700, "Configuration Wizard");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create theme
    auto theme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Colors.WHITE;
        },

        &GluiLabel.styleKey: style!q{
            textColor = Colors.BLACK;
        },

        &GluiButton!GluiLabel.styleKey: style!q{
            backgroundColor = Color(0, 0, 0, 0);
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.hoverStyleKey: style!q{
            backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.pressStyleKey: style!q{
            backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },

        &GluiTextInput.styleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            textColor = Colors.BLACK;
        },
        &GluiTextInput.emptyStyleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            textColor = Color(0x00, 0x00, 0x00, 0xaa);

        },
        &GluiTextInput.focusStyleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xff);
            textColor = Colors.BLACK;
        }
    ];

    auto blueTheme = theme.dup; //Color(0x55, 0xcd, 0xfc, 0xff)
    blueTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0x33, 0xab, 0xda, 0xff);
    };
    auto pinkTheme = theme.dup; //Color(0xf7, 0xa8, 0xb8, 0xff)
    pinkTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0xd5, 0x86, 0x96, 0xff);
    };
    auto whiteTheme = theme.dup; //Color(0xff, 0xff, 0xff, 0xff)
    whiteTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
    };

    auto whiteText = style!q{
        textColor = Colors.WHITE;
    };
    auto pinkText = style!q{
        textColor = Color(0xf7, 0xa8, 0xb8, 0xff);
    };

    Layout fill = layout!(1, "fill");

    // Save IDs
    GluiRichLabel staticPreviewLabel;
    GluiRichLabel connectionTypeLabel;

    GluiTextInput serverInput;
    GluiTextInput serverNameInput;
    GluiTextInput shareInput;
    GluiTextInput linkInput;
    GluiTextInput endMessageInput;

    GluiNode credNode;
    GluiTextInput usernameInput;
    GluiTextInput passwordInput;
    GluiNode workgroupNode;
    GluiTextInput workgroupInput;

    auto toggleStaticPreview = () {
        staticPreviewLabel.clear();
        staticPreviewLabel.push("Static Preview is \n");

        config.staticPreview = !config.staticPreview;
        config.save();
        staticPreviewLabel.push(whiteText, config.staticPreview ? "enabled!" : "disabled!");
    };

    auto changeConnectionType = () {
        connectionTypeLabel.clear();
        connectionTypeLabel.push("Connection Type:\n");

        config.connectionType = cast(ConnectionType)((config.connectionType + 1) % 3);
        config.save();

        connectionTypeLabel.push(pinkText, format("%s ", config.connectionType));
    };

    auto saveConnectionOptions = () {
        config.server = serverInput.value;
        config.serverName = serverNameInput.value;
        config.share = shareInput.value;
        config.link = linkInput.value;
        config.endMessage = endMessageInput.value;

        config.save();
    };

    auto loadConnectionOptions = () {
        serverInput.value = config.server;
        serverNameInput.value = config.serverName;
        shareInput.value = config.share;
        linkInput.value = config.link;
        endMessageInput.value = config.endMessage;

        serverInput.size.x = serverInput.size.x * 2;
        serverNameInput.size.x = serverNameInput.size.x * 2;
        shareInput.size.x = shareInput.size.x * 2;
        linkInput.size.x = linkInput.size.x * 2;
        endMessageInput.size.x = endMessageInput.size.x * 2;
    };

    auto loadCredFile = () {
        if(config.connectionType == ConnectionType.curl) {
            credNode.hide();
        } else {
            credNode.show();
        }

        string[] credFile = split(Helpers.readWholeFile(config.credFile), "\n");

        string username = "";
        string password = "";
        string workgroup = "";

        if(config.connectionType == ConnectionType.smb) {
            username = credFile[0];
            workgroup = credFile[1];
            password = credFile[2];

            workgroupNode.show();
        } else if(config.connectionType == ConnectionType.ftp) {
            username = credFile[0];
            password = credFile[1];

            workgroupNode.hide();
        }

        usernameInput.value = username;
        passwordInput.value = password;
        workgroupInput.value = workgroup;
    };

    auto saveCredFile = () {
        string stringToWrite = "";

        if(config.connectionType == ConnectionType.smb) {
            stringToWrite = format("%s\n%s\n%s", usernameInput.value, workgroupInput.value, passwordInput.value);
        } else if(config.connectionType == ConnectionType.ftp) {
            stringToWrite = format("%s\n%s", usernameInput.value, passwordInput.value);
        }

        std.file.write(expandTilde(config.credFile), stringToWrite);
    };

    auto root = vframe(theme, fill,
        vframe(layout!("fill", "start"),
            hframe(
                layout!"center",

                label(layout!"center", "NotShareX Configuration Wizard!"),
            )
        ),

        hframe(fill,
            vframe(blueTheme, fill, 
            
            ),

            vframe(pinkTheme, fill,
                staticPreviewLabel = richLabel(
                    layout!(1, "center"),
                    "Static Preview is \n",
                    whiteText, "disabled!", null,
                ),
                button(layout!(1, "center"),
                    "Press to toggle ",
                    () {
                        toggleStaticPreview();
                    }
                ),
            ),

            vframe(whiteTheme, fill, 
                connectionTypeLabel = richLabel(
                    layout!(1, "center"),
                    "Connection Type:\n",
                    pinkText, format("%s", config.connectionType), null,
                ),
                button(layout!(1, "center"),
                    "Press to change ",
                    () {
                        changeConnectionType();
                    }
                ),
            ),

            vframe(pinkTheme, fill, 
                vframe(pinkTheme, fill,
                    vframe(pinkTheme, fill, 
                        richLabel(layout!(1, "center"), 
                            "Server:"
                        ),
                        serverInput = textInput(layout!(1, "center"), "Server..."),
                    ),
                    vframe(pinkTheme, fill, 
                        richLabel(layout!(1, "center"), 
                            "Server Name:"
                        ),
                        serverNameInput = textInput(layout!(1, "center"), "Server Name..."),
                    ),
                    vframe(pinkTheme, fill, 
                        richLabel(layout!(1, "center"), 
                            "Share:"
                        ),
                        shareInput = textInput(layout!(1, "center"), "Share..."),
                    ),
                    vframe(pinkTheme, fill, 
                        richLabel(layout!(1, "center"), 
                            "Link:"
                        ),
                        linkInput = textInput(layout!(1, "center"), "Link..."),
                    ),
                    vframe(pinkTheme, fill, 
                        richLabel(layout!(1, "center"), 
                            "End Message:"
                        ),
                        endMessageInput = textInput(layout!(1, "center"), "End Message..."),
                    ),
                ),
                button(layout!(1, "center"),
                    "Save ",
                    () {
                        saveConnectionOptions();
                    }
                ),
            ),

            vframe(blueTheme, fill, 
                credNode = vframe(blueTheme, fill, 
                    usernameInput = textInput(layout!(1, "center"), "Username..."),
                    passwordInput = textInput(layout!(1, "center"), "Password..."),
                    workgroupNode = vframe(blueTheme, fill, 
                        workgroupInput = textInput(layout!(1, "center"), "Workgroup...")
                    )
                ),
                button(layout!(1, "center"),
                    "Save ",
                    () {
                        saveCredFile();
                    }
                ),
            ),
        )
    );

    loadConnectionOptions();
    loadCredFile();

    //Render the window
    while (!WindowShouldClose) {
        BeginDrawing();
            SetMouseCursor(MouseCursor.MOUSE_CURSOR_DEFAULT);
            ClearBackground(Colors.BLACK);
            root.draw();
        EndDrawing();
    }
}

/// Takes a screenshot
void screenshot(Config config) {
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
            Helpers.curl(config);

            break;
        }

        default: {
            writeln("Unknown connection type!");

            assert(0);
        }
    }

    Helpers.copyToClipboard(std.string.strip(finalLink));
    Helpers.espeak(config.endMessage);
}