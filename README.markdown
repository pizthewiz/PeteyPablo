
# Petey Pablo
a lightweight quartz composer patch to render a PDF document by page

### HOW TO INSTALL
move PeteyPablo.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* the Location input should be a fully qualified url with scheme, or a file path relative to the composition
* the Width Pixels and Height Pixels inputs default to the main screen's resolution, and is treated as the maximum in each dimension while maintaining the aspect ratio of the PDF document.
* render occurs on change of any input or when the Render signal goes high.
