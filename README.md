# DAE-to-RealityKit
Extensions to convert 3D models in DAE format to RealityKit entities.

![Example](screenshotDaeToRealityKit.png)

These extensions allow importing of DAE models at runtime using a custom `Collada` parser.
Most of the time, you will asynchronously load an entity using the static extension methods, for example, if you have a `URL` for a DAE file location:
```swift
let entity: ModelEntity? = await ModelEntity.fromDAEAsset(url: url)
```

Alternately, if you have already loaded the file as a Swift `Data` object (i.e., `Data(contentsOf: url)`:
```swift
let entity: ModelEntity? = await ModelEntity.fromDAEAsset(data: data)
```

An optional `options` data structure may be passed to either of these, which can be used to specify whether to use the custom `Collada` parser, or using `SceneKit` as an intermediate step.
Most of the time, this argument can be omitted, in which case the code will detect which is the best to use.

