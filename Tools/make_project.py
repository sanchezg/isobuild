# Copyright (C) 2026 gsanz.dev
# Licensed under GNU GPL version 3 only, with the additional notice-preservation
# term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

"""Generate a dependency-free Xcode project using the checked-in Swift files."""
from pathlib import Path
from hashlib import sha1
import json

root = Path(__file__).resolve().parents[1]
project_dir = root / "IsoBuild.xcodeproj"
project_dir.mkdir(exist_ok=True)


def key(name):
    return sha1(name.encode()).hexdigest()[:24].upper()


objects = []


def add(name, body):
    entry = f"\t\t{key(name)} = {{ {body} }};"
    objects.append("\n".join(line.rstrip() for line in entry.splitlines()))
    return key(name)


files = sorted(root.glob("Sources/**/*.swift"))
file_refs, build_refs = [], []
for file in files:
    relative = file.relative_to(root).as_posix()
    file_refs.append(add(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{relative}"; sourceTree = SOURCE_ROOT;'))
    build_refs.append(add("build:" + relative, f"isa = PBXBuildFile; fileRef = {key(relative)};"))

product = add("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = IsoBuild.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = add("products", f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
resource_refs, resource_builds = [], []
for resource in ["LICENSE", "ATTRIBUTION.md"]:
    resource_refs.append(add(resource, f'isa = PBXFileReference; lastKnownFileType = text; path = "{resource}"; sourceTree = SOURCE_ROOT;'))
    resource_builds.append(add("build:" + resource, f"isa = PBXBuildFile; fileRef = {key(resource)};"))
language_refs = []
for language in ["en", "es"]:
    resource = f"Resources/{language}.lproj/Localizable.strings"
    language_refs.append(add(resource, f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {language}; path = "{resource}"; sourceTree = SOURCE_ROOT;'))
localized_strings = add("localized-strings", f'isa = PBXVariantGroup; children = ({",".join(language_refs)},); name = Localizable.strings; sourceTree = "<group>";')
resource_refs.append(localized_strings)
resource_builds.append(add("build:localized-strings", f"isa = PBXBuildFile; fileRef = {localized_strings};"))
main_group = add("main-group", f'isa = PBXGroup; children = ({",".join(file_refs + resource_refs + [products])},); sourceTree = "<group>";')
sources = add("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(build_refs)},); runOnlyForDeploymentPostprocessing = 0;")
frameworks = add("frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
resources = add("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;")
source_script = json.dumps('set -eu\n/usr/bin/python3 "$SRCROOT/Tools/package_source.py" --output "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/IsoBuild-Source.zip"\n')
archive_inputs = {"", "LICENSE", "ATTRIBUTION.md", "LICENSING.md", "README.md", "DECISIONS.md", "AGENTS.md", "Package.swift", ".gitignore",
                  "IsoBuild.xcodeproj/project.pbxproj", "IsoBuild.xcodeproj/xcshareddata", "IsoBuild.xcodeproj/xcshareddata/xcschemes",
                  "IsoBuild.xcodeproj/xcshareddata/xcschemes/IsoBuild.xcscheme"}
for directory in ["Sources", "Tests", "Resources", "Config", "Tools", "IsoBuild.xcodeproj"]:
    archive_inputs.add(directory)
    archive_inputs.update(path.relative_to(root).as_posix() for path in (root / directory).rglob("*")
                          if "xcuserdata" not in path.parts and "__pycache__" not in path.parts)
input_paths = ",".join(json.dumps("$(SRCROOT)/" + path) for path in sorted(archive_inputs))
source_archive = add("source-archive", f'isa = PBXShellScriptBuildPhase; alwaysOutOfDate = 1; buildActionMask = 2147483647; files = (); inputPaths = ({input_paths},); name = "Bundle corresponding source"; outputPaths = ("$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/IsoBuild-Source.zip",); runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = {source_script};')

project_configs, target_configs = [], []
for config in ["Debug", "Release"]:
    settings = """
        CLANG_ENABLE_MODULES = YES;
        CLANG_ENABLE_OBJC_ARC = YES;
        ENABLE_USER_SCRIPT_SANDBOXING = YES;
        SDKROOT = iphoneos;
        IPHONEOS_DEPLOYMENT_TARGET = 26.0;
        SWIFT_VERSION = 6.0;
    """
    settings += "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\"; DEBUG_INFORMATION_FORMAT = dwarf;" if config == "Debug" else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    if config == "Debug":
        settings += ' SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";'
    project_configs.append(add(f"project-{config}", f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ {settings} }};'))
    settings = """
        PRODUCT_NAME = IsoBuild;
        PRODUCT_BUNDLE_IDENTIFIER = net.gonzalo.IsoBuild;
        TARGETED_DEVICE_FAMILY = 2;
        GENERATE_INFOPLIST_FILE = YES;
        INFOPLIST_FILE = Config/Info.plist;
        INFOPLIST_KEY_CFBundleDisplayName = IsoBuild;
        INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.graphics-design";
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        MARKETING_VERSION = 0.1.0;
        CURRENT_PROJECT_VERSION = 1;
        CODE_SIGN_STYLE = Automatic;
        SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        SUPPORTS_MACCATALYST = NO;
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
        SWIFT_EMIT_LOC_STRINGS = YES;
    """
    target_configs.append(add(f"target-{config}", f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ {settings} }};'))

project_config_list = add("project-configs", f"isa = XCConfigurationList; buildConfigurations = ({','.join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target_config_list = add("target-configs", f"isa = XCConfigurationList; buildConfigurations = ({','.join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target = add("target", f'isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = ({sources},{frameworks},{resources},{source_archive},); buildRules = (); dependencies = (); name = IsoBuild; productName = IsoBuild; productReference = {product}; productType = "com.apple.product-type.application";')
add("project", f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 2700; LastUpgradeCheck = 2700; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 27.0; }}; }}; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 15.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,es,Base,); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')

(project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 60;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {key('project')};\n}}\n")
scheme_dir = project_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="IsoBuild.app" BlueprintName="IsoBuild" ReferencedContainer="container:IsoBuild.xcodeproj"/>'
(scheme_dir / "IsoBuild.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated {project_dir}")
