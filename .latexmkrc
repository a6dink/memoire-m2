# Configuration latexmk pour le mémoire
$pdf_mode = 1;
$pdflatex = 'pdflatex -interaction=nonstopmode -synctex=1 -file-line-error %O %S';
$bibtex_use = 2;
$clean_ext = 'acn acr alg glg glo gls ist bbl bcf run.xml synctex.gz tdo';

# Génération du glossaire / liste d'acronymes
add_cus_dep('acn', 'acr', 0, 'makeglossaries');
add_cus_dep('glo', 'gls', 0, 'makeglossaries');
sub makeglossaries {
    my ($base_name, $path) = fileparse($_[0]);
    pushd $path;
    my $return = system "makeglossaries", $base_name;
    popd;
    return $return;
}
