/**
 # DAE_to_RealityKit
 https://github.com/radcli14/DAE-to-RealityKit

 ## Installation
 
 The package may be installed using Swift Package Manager, in XCode, as follows:github.com/radcli14/DAE-to-RealityKit
 1. From the `File` menu, select `Add Package Dependencies`.
 2. In the search bar in the upper right, enter `https://github.com/radcli14/DAE-to-RealityKit`.
 3. Make sure your project is selected in the `Add to Project` line, then click the `Add Package` button in the lower right.
 4. Make sure your target is selected in the `Add to Target` line, then click the `Add Package` button again.

 ## User Quickstart
 
 To load an entity from a DAE-formatted XML file at a URL:
 ```swift
 let entity: ModelEntity? = await ModelEntity.fromDAEAsset(url: url)
 ```
 or, you can provide a `Data` object
 ```swift
 let data = Data(contentsOf: url)
 let entity: ModelEntity? = await ModelEntity.fromDAEAsset(data: data)
 ```
 
 ## Developer Guidelines
 
 The directories are structured as follows:
 - **RealityKit**:: Extensions on `ModelEntity` that allow loading from DAE-formatted XML, as in the quickstart
 - **Collada**: Data structure derived from the COLLADA 1.4.1 Schema, parses from XML using the [XMLCoder](https://github.com/MaxDesiatov/XMLCoder) package
 - **SceneKit**: Extensions on SceneKit objects to provide data that can aid in conversion to RealityKit
 
 - Note: The SceneKit extensions represented an early attempt to simply use the SceneKit DAE loader as an intermediate stage to obtaining the RealityKit entity. This worked in the case that the DAE files are provided in the bundle at comple-time, which XCode automatically converts to scene files. However, that does not work for DAE files that are outside of the bundle and loaded at runtime. Therefore, the Collada extensions are created as a more general-purpose DAE parser.
*/

