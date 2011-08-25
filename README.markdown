
# Petey Pablo
a lightweight quartz composer patch to render a PDF document by page

### HOW TO INSTALL
move PeteyPablo.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* the Location input should be a fully qualified url with scheme, or a relative to the composition file path
* the Width Pixels and Height Pixels inputs default to the main screen's resolution and are relevant for relative-sized content. fixed-size content will render into a view of the destination size, but will then be resized to the document's native size. if the desired destination size is a hard limit, one should compare the output image size to the desired input size and transform accordingly.
* render occurs on change of any input or when the Render signal goes high.
