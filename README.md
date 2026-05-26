# DAE-to-RealityKit
Extensions to convert 3D models in DAE format to RealityKit entities.
This repository is developed as part of the [Augmented Reality Mobile Robotics (ARMOR) project](https://armor.dc-engineer.com).
Below are examples of Universal Robot Description Format (URDF) files containing DAE models, which have been loaded using this utility, and rendered in ARMOR.

| Anymal | Panda | ABB IRB 6640 |
|---|---|---|
| ![Anymal](Images/anymal.png) | ![Panda](Images/panda.png) | ![ABB IRB 6640](Images/abb_irb6640.png) |

These extensions allow importing of DAE models at runtime using a custom `Collada` parser.
Both loading methods are `async throws` — they return a non-optional `ModelEntity` on success and throw a `DAEImportError` on failure.

Load from a `URL`:
```swift
let entity: ModelEntity = try await ModelEntity.fromDAEAsset(url: url)
```

Load from a `Data` object (e.g. `Data(contentsOf: url)`):
```swift
let entity: ModelEntity = try await ModelEntity.fromDAEAsset(data: data)
```

An optional `DAEImportOptions` parameter controls which parser is used. The default `.auto` loader inspects the data to choose between the custom COLLADA parser and SceneKit, with automatic fallback if the first attempt fails. Pass `.custom` or `.sceneKit` to force a specific parser:
```swift
let entity: ModelEntity = try await ModelEntity.fromDAEAsset(url: url, options: .init(loader: .custom))
```

## Installation

### Xcode

1. From the `File` menu, select `Add Package Dependencies`.
2. In the search bar in the upper right, enter `https://github.com/radcli14/DAE-to-RealityKit`.
3. Make sure your project is selected in the `Add to Project` line, then click the `Add Package` button in the lower right.
4. Make sure your target is selected in the `Add to Target` line, then click the `Add Package` button again.

### Swift Package Manager

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/radcli14/DAE-to-RealityKit", from: "0.5.0")
]
```

Then add `"DAE-to-RealityKit"` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "DAE-to-RealityKit", package: "DAE-to-RealityKit")
    ]
)
```

Requires iOS 18+ or macOS 15+.


## Developer Guidelines
 
The directories are structured as follows:
 - **RealityKit**:: Extensions on `ModelEntity` that allow loading from DAE-formatted XML, as in the quickstart
 - **Collada**: Data structure derived from the COLLADA 1.4.1 Schema, parses from XML using the [XMLCoder](https://github.com/MaxDesiatov/XMLCoder) package
 - **SceneKit**: Extensions on SceneKit objects to provide data that can aid in conversion to RealityKit
 
### Note Regarding SceneKit
 
The SceneKit extensions represented an early attempt to simply use the SceneKit DAE loader as an intermediate stage to obtaining the RealityKit entity. 
This worked in the case that the DAE files are provided in the bundle at comple-time, which XCode automatically converts to scene files. 
However, that does not work for DAE files that are outside of the bundle and loaded at runtime. 
Therefore, the Collada extensions are created as a more general-purpose DAE parser.

Since SceneKit is deprecated, anticipate that the SceneKit extensions may ultimately be removed.
In this case, the directories are organized such that files in the Collada folder depend only on `XMLCoder`, while the `RealityKit` dependencies are fully contained in that folder.
