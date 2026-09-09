#!/usr/bin/env python3
import os
import uuid

def gen_id(prefix=""):
    return (prefix + uuid.uuid4().hex[:24-len(prefix)]).upper()

# Shared files
shared_models = [
    "Shared/Models/MediaType.swift",
    "Shared/Models/StreamingProvider.swift",
    "Shared/Models/VideoTrailer.swift",
    "Shared/Models/CastMember.swift",
    "Shared/Models/MediaItem.swift",
    "Shared/Models/WatchlistRecord.swift"
]

shared_services = [
    "Shared/Services/TMDBService.swift",
    "Shared/Services/WatchlistStore.swift",
    "Shared/Services/DiscoveryEngine.swift"
]

shared_components = [
    "Shared/Components/CachedAsyncImage.swift",
    "Shared/Components/RatingBadge.swift",
    "Shared/Components/StreamingProviderPill.swift",
    "Shared/Components/PosterCardView.swift",
    "Shared/Components/BackdropCardView.swift"
]

shared_all = shared_models + shared_services + shared_components

# iOS specific files
ios_files = [
    "iOS/AnodeApp.swift",
    "iOS/Views/MainTabView.swift",
    "iOS/Views/DiscoverView.swift",
    "iOS/Views/StreamingPulseView.swift",
    "iOS/Views/SearchView.swift",
    "iOS/Views/WatchlistView.swift",
    "iOS/Views/MediaDetailView.swift"
]

# tvOS specific files
tvos_files = [
    "tvOS/AnodeTVApp.swift",
    "tvOS/Views/TVHomeView.swift",
    "tvOS/Views/TVMediaCardView.swift",
    "tvOS/Views/TVMediaDetailView.swift",
    "tvOS/Views/TVWatchlistView.swift",
    "tvOS/Views/TVSearchView.swift"
]

# File references
file_refs = {}
for path in shared_all + ios_files + tvos_files:
    file_refs[path] = gen_id("FREF")

ios_assets_ref = gen_id("FREF")
tvos_assets_ref = gen_id("FREF")
ios_plist_ref = gen_id("FREF")
tvos_plist_ref = gen_id("FREF")

# Build files for iOS
ios_build_files = {}
for path in shared_all + ios_files:
    ios_build_files[path] = gen_id("IOSB")
ios_assets_build = gen_id("IOSB")

# Build files for tvOS
tvos_build_files = {}
for path in shared_all + tvos_files:
    tvos_build_files[path] = gen_id("TVOB")
tvos_assets_build = gen_id("TVOB")

# Targets & Products
ios_product_ref = gen_id("PRD1")
tvos_product_ref = gen_id("PRD2")
ios_target_id = gen_id("TRG1")
tvos_target_id = gen_id("TRG2")

# Build Phases
ios_sources_phase = gen_id("PHS1")
ios_frameworks_phase = gen_id("PHF1")
ios_resources_phase = gen_id("PHR1")

tvos_sources_phase = gen_id("PHS2")
tvos_frameworks_phase = gen_id("PHF2")
tvos_resources_phase = gen_id("PHR2")

# Configs
proj_debug_cfg = gen_id("PDCF")
proj_release_cfg = gen_id("PRCF")
proj_cfg_list = gen_id("PCLF")

ios_debug_cfg = gen_id("IDC1")
ios_release_cfg = gen_id("IRC1")
ios_cfg_list = gen_id("ICL1")

tvos_debug_cfg = gen_id("TDC2")
tvos_release_cfg = gen_id("TRC2")
tvos_cfg_list = gen_id("TCL2")

# Groups
main_group_id = gen_id("MGRP")
shared_group_id = gen_id("SGRP")
models_group_id = gen_id("MOGP")
services_group_id = gen_id("SRGP")
components_group_id = gen_id("CPGP")
ios_group_id = gen_id("IOGP")
ios_views_group_id = gen_id("IVGP")
tvos_group_id = gen_id("TVGP")
tvos_views_group_id = gen_id("TVVG")
products_group_id = gen_id("PRGP")

proj_id = gen_id("PROJ")

lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")

# PBXBuildFile section
lines.append("\n/* Begin PBXBuildFile section */")
for path, b_id in ios_build_files.items():
    f_id = file_refs[path]
    fname = os.path.basename(path)
    lines.append(f"\t\t{b_id} /* {fname} in Sources (iOS) */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {fname} */; }};")
lines.append(f"\t\t{ios_assets_build} /* Assets.xcassets in Resources (iOS) */ = {{isa = PBXBuildFile; fileRef = {ios_assets_ref} /* Assets.xcassets */; }};")

for path, b_id in tvos_build_files.items():
    f_id = file_refs[path]
    fname = os.path.basename(path)
    lines.append(f"\t\t{b_id} /* {fname} in Sources (tvOS) */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {fname} */; }};")
lines.append(f"\t\t{tvos_assets_build} /* Assets.xcassets in Resources (tvOS) */ = {{isa = PBXBuildFile; fileRef = {tvos_assets_ref} /* Assets.xcassets */; }};")
lines.append("/* End PBXBuildFile section */")

# PBXFileReference section
lines.append("\n/* Begin PBXFileReference section */")
for path, f_id in file_refs.items():
    fname = os.path.basename(path)
    lines.append(f"\t\t{f_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{fname}\"; sourceTree = \"<group>\"; }};")

lines.append(f"\t\t{ios_assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{tvos_assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{ios_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{tvos_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")

lines.append(f"\t\t{ios_product_ref} /* Anode.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Anode.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
lines.append(f"\t\t{tvos_product_ref} /* Anode-tvOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"Anode-tvOS.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
lines.append("/* End PBXFileReference section */")

# Frameworks Build Phases
lines.append("\n/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{ios_frameworks_phase} /* Frameworks (iOS) */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
lines.append(f"\t\t{tvos_frameworks_phase} /* Frameworks (tvOS) */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
lines.append("/* End PBXFrameworksBuildPhase section */")

# Groups
lines.append("\n/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group_id} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{shared_group_id} /* Shared */,")
lines.append(f"\t\t\t\t{ios_group_id} /* iOS */,")
lines.append(f"\t\t\t\t{tvos_group_id} /* tvOS */,")
lines.append(f"\t\t\t\t{products_group_id} /* Products */,")
lines.append("\t\t\t);")
lines.append("\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# Shared group
lines.append(f"\t\t{shared_group_id} /* Shared */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{models_group_id} /* Models */,")
lines.append(f"\t\t\t\t{services_group_id} /* Services */,")
lines.append(f"\t\t\t\t{components_group_id} /* Components */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Shared;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{models_group_id} /* Models */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in shared_models:
    lines.append(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Models;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{services_group_id} /* Services */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in shared_services:
    lines.append(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Services;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{components_group_id} /* Components */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in shared_components:
    lines.append(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Components;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# iOS group
lines.append(f"\t\t{ios_group_id} /* iOS */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{file_refs['iOS/AnodeApp.swift']} /* AnodeApp.swift */,")
lines.append(f"\t\t\t\t{ios_views_group_id} /* Views */,")
lines.append(f"\t\t\t\t{ios_assets_ref} /* Assets.xcassets */,")
lines.append(f"\t\t\t\t{ios_plist_ref} /* Info.plist */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = iOS;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{ios_views_group_id} /* Views */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in ios_files[1:]:
    lines.append(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Views;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# tvOS group
lines.append(f"\t\t{tvos_group_id} /* tvOS */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{file_refs['tvOS/AnodeTVApp.swift']} /* AnodeTVApp.swift */,")
lines.append(f"\t\t\t\t{tvos_views_group_id} /* Views */,")
lines.append(f"\t\t\t\t{tvos_assets_ref} /* Assets.xcassets */,")
lines.append(f"\t\t\t\t{tvos_plist_ref} /* Info.plist */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = tvOS;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

lines.append(f"\t\t{tvos_views_group_id} /* Views */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
for p in tvos_files[1:]:
    lines.append(f"\t\t\t\t{file_refs[p]} /* {os.path.basename(p)} */,")
lines.append("\t\t\t);")
lines.append("\t\t\tpath = Views;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# Products group
lines.append(f"\t\t{products_group_id} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{ios_product_ref} /* Anode.app */,")
lines.append(f"\t\t\t\t{tvos_product_ref} /* Anode-tvOS.app */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")
lines.append("/* End PBXGroup section */")

# Native Targets
lines.append("\n/* Begin PBXNativeTarget section */")
# iOS Target
lines.append(f"\t\t{ios_target_id} /* Anode-iOS */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {ios_cfg_list} /* Build configuration list for PBXNativeTarget \"Anode-iOS\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{ios_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{ios_frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{ios_resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = \"Anode-iOS\";")
lines.append("\t\t\tproductName = \"Anode\";")
lines.append(f"\t\t\tproductReference = {ios_product_ref} /* Anode.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")

# tvOS Target
lines.append(f"\t\t{tvos_target_id} /* Anode-tvOS */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {tvos_cfg_list} /* Build configuration list for PBXNativeTarget \"Anode-tvOS\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{tvos_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{tvos_frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{tvos_resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = \"Anode-tvOS\";")
lines.append("\t\t\tproductName = \"Anode-tvOS\";")
lines.append(f"\t\t\tproductReference = {tvos_product_ref} /* Anode-tvOS.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")

# Project section
lines.append("\n/* Begin PBXProject section */")
lines.append(f"\t\t{proj_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
lines.append("\t\t\t\tTargetAttributes = {")
lines.append(f"\t\t\t\t\t{ios_target_id} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t};")
lines.append(f"\t\t\t\t\t{tvos_target_id} = {{")
lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
lines.append("\t\t\t\t\t};")
lines.append("\t\t\t\t};")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject \"Anode\" */;")
lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
lines.append("\t\t\tdevelopmentRegion = en;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group_id};")
lines.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
lines.append("\t\t\tprojectDirPath = \"\";")
lines.append("\t\t\tprojectRoot = \"\";")
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{ios_target_id} /* Anode-iOS */,")
lines.append(f"\t\t\t\t{tvos_target_id} /* Anode-tvOS */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")

# Resources Build Phases
lines.append("\n/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{ios_resources_phase} /* Resources (iOS) */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{ios_assets_build} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")

lines.append(f"\t\t{tvos_resources_phase} /* Resources (tvOS) */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{tvos_assets_build} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")

# Sources Build Phases
lines.append("\n/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{ios_sources_phase} /* Sources (iOS) */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in shared_all + ios_files:
    b_id = ios_build_files[path]
    fname = os.path.basename(path)
    lines.append(f"\t\t\t\t{b_id} /* {fname} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")

lines.append(f"\t\t{tvos_sources_phase} /* Sources (tvOS) */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in shared_all + tvos_files:
    b_id = tvos_build_files[path]
    fname = os.path.basename(path)
    lines.append(f"\t\t\t\t{b_id} /* {fname} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")

# Build Configurations
lines.append("\n/* Begin XCBuildConfiguration section */")
# Project level
lines.append(f"\t\t{proj_debug_cfg} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
lines.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
lines.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
lines.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
lines.append("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (")
lines.append("\t\t\t\t\t\"DEBUG=1\",")
lines.append("\t\t\t\t\t\"$(inherited)\",")
lines.append("\t\t\t\t);")
lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
lines.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{proj_release_cfg} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
lines.append("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
lines.append("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
lines.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
lines.append("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
lines.append("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = \"wholemodule\";")
lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")

# iOS Target configs
lines.append(f"\t\t{ios_debug_cfg} /* Debug (iOS) */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
lines.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
lines.append("\t\t\t\tENABLE_PREVIEWS = YES;")
lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
lines.append("\t\t\t\tINFOPLIST_FILE = \"iOS/Info.plist\";")
lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";")
lines.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.anode.ios;")
lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
lines.append("\t\t\t\tSDKROOT = iphoneos;")
lines.append("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{ios_release_cfg} /* Release (iOS) */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
lines.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
lines.append("\t\t\t\tENABLE_PREVIEWS = YES;")
lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
lines.append("\t\t\t\tINFOPLIST_FILE = \"iOS/Info.plist\";")
lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";")
lines.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.anode.ios;")
lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
lines.append("\t\t\t\tSDKROOT = iphoneos;")
lines.append("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")

# tvOS Target configs
lines.append(f"\t\t{tvos_debug_cfg} /* Debug (tvOS) */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
lines.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
lines.append("\t\t\t\tENABLE_PREVIEWS = YES;")
lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
lines.append("\t\t\t\tINFOPLIST_FILE = \"tvOS/Info.plist\";")
lines.append("\t\t\t\tTVOS_DEPLOYMENT_TARGET = 17.0;")
lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";")
lines.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.anode.tvos;")
lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
lines.append("\t\t\t\tSDKROOT = appletvos;")
lines.append("\t\t\t\tSUPPORTED_PLATFORMS = \"appletvos appletvsimulator\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"3\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Debug;")
lines.append("\t\t};")

lines.append(f"\t\t{tvos_release_cfg} /* Release (tvOS) */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
lines.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
lines.append("\t\t\t\tENABLE_PREVIEWS = YES;")
lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
lines.append("\t\t\t\tINFOPLIST_FILE = \"tvOS/Info.plist\";")
lines.append("\t\t\t\tTVOS_DEPLOYMENT_TARGET = 17.0;")
lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";")
lines.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.anode.tvos;")
lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
lines.append("\t\t\t\tSDKROOT = appletvos;")
lines.append("\t\t\t\tSUPPORTED_PLATFORMS = \"appletvos appletvsimulator\";")
lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = \"3\";")
lines.append("\t\t\t};")
lines.append("\t\t\tname = Release;")
lines.append("\t\t};")
lines.append("/* End XCBuildConfiguration section */")

# XCConfigurationList section
lines.append("\n/* Begin XCConfigurationList section */")
lines.append(f"\t\t{proj_cfg_list} /* Build configuration list for PBXProject \"Anode\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{proj_debug_cfg} /* Debug */,")
lines.append(f"\t\t\t\t{proj_release_cfg} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")

lines.append(f"\t\t{ios_cfg_list} /* Build configuration list for PBXNativeTarget \"Anode-iOS\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{ios_debug_cfg} /* Debug */,")
lines.append(f"\t\t\t\t{ios_release_cfg} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")

lines.append(f"\t\t{tvos_cfg_list} /* Build configuration list for PBXNativeTarget \"Anode-tvOS\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{tvos_debug_cfg} /* Debug */,")
lines.append(f"\t\t\t\t{tvos_release_cfg} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")

lines.append("\t};")
lines.append(f"\trootObject = {proj_id} /* Project object */;")
lines.append("}")

os.makedirs("Anode.xcodeproj", exist_ok=True)
with open("Anode.xcodeproj/project.pbxproj", "w") as f:
    f.write("\n".join(lines) + "\n")

print("Generated Anode.xcodeproj successfully!")
