# Hydrate

来听听 ASMR 吧！

<img src="Artwork/AppIcon.png" alt="App 图标" width=200 height=200 style="border-radius: 30px;" />

Hydrate 是 iOS 端的 ASMR 音频浏览及播放器，内容来自 [asmr.one](https://asmr.one)。

App 采用类似 Apple Music 的 UI 设计，并支持滚动字幕，助你在听音声时拥有更加“原生”的体验。

<div class="horizontal-scroll-container">
    <div class="horizontal-scroll-item flex hstack@md vstack" style="background-image: url(Artwork/Screenshots/Home.png); @media (prefers-color-scheme: dark) { style="background-image: url(Artwork/Screenshots/Home_Dark.png); }"></div>
    <div class="horizontal-scroll-item flex hstack@md vstack" style="background-image: url(Artwork/Screenshots/WorkDetail.png); @media (prefers-color-scheme: dark) { style="background-image: url(Artwork/Screenshots/WorkDetail_Dark.png); }"></div>
    <div class="horizontal-scroll-item flex hstack@md vstack" style="background-image: url(Artwork/Screenshots/Library.png); @media (prefers-color-scheme: dark) { style="background-image: url(Artwork/Screenshots/Library_Dark.png); }"></div>
    <div class="horizontal-scroll-item flex hstack@md vstack" style="background-image: url(Artwork/Screenshots/Search.png); @media (prefers-color-scheme: dark) { style="background-image: url(Artwork/Screenshots/Search_Dark.png); }"></div>
</div>

## 构建

1. Clone 项目，打开 `xcodeproj` 文件；
2. 等待软件包依赖项处理完成；
3. 转到文件浏览边栏 → Xcode 项目（Hydrate）→ TARGETS → Hydrate → Signing & Capabilities，将团队更改为你自己的，并修改一个不冲突的包标识符；
4. 构建 App。

## Disclaimer

Hydrate 用于学习 Swift 以及 SwiftUI 开发以及供个人、非商业性地使用，内容版权属于 [asmr.one](https://asmr.one) 或音声原发布平台以及音声作者本人。

<style>
.horizontal-scroll-container {
    display: flex;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch;
    gap: 10px;
    scrollbar-width: none;
}
.horizontal-scroll-item {
    background-color: #303132;
    box-shadow: 4px 4px 6px #232323, -4px -4px 6px #3E3F46;
    border-radius: 20px;
    padding: 30px;
    margin: 10px 20px;
    scroll-snap-align: center;
    flex: 0 0 50%;
    height: 80vh;
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
}
</style>
