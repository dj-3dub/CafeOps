
# Render CafeOps architecture with Graphviz
ARCH_DOT=cafeops_architecture_public.dot
ARCH_SVG=cafeops_architecture_public.svg
ARCH_PNG=cafeops_architecture_public.png

.PHONY: arch clean

arch:
\t@dot -Tsvg $(ARCH_DOT) -o $(ARCH_SVG)
\t@dot -Tpng $(ARCH_DOT) -o $(ARCH_PNG)
\t@echo "Wrote $(ARCH_SVG) and $(ARCH_PNG)"

clean:
\t@rm -f $(ARCH_SVG) $(ARCH_PNG)
\t@echo "Cleaned generated files"
