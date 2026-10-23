#include <QApplication>
#include <QColor>
#include <QDebug>
#include <QPalette>
#include <QProxyStyle>
#include <QSettings>
#include <QStandardPaths>
#include <QStyle>
#include <QStringList>

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    if (argc != 2) {
        qCritical() << "Expected a qtct configuration directory name";
        return 1;
    }

    QStyle *style = app.style();
    while (auto *proxy = qobject_cast<QProxyStyle *>(style)) {
        style = proxy->baseStyle();
    }
    if (style->objectName().compare("Fusion", Qt::CaseInsensitive) != 0) {
        qCritical() << "Unexpected widget style:" << style->objectName();
        return 1;
    }

    const QString qtct = QString::fromLocal8Bit(argv[1]);
    const QString configHome = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QSettings config(configHome + "/" + qtct + "/" + qtct + ".conf", QSettings::IniFormat);
    QSettings colors(config.value("Appearance/color_scheme_path").toString(), QSettings::IniFormat);
    const QPalette actual = app.palette();
    const QPalette::ColorGroup groups[] = {QPalette::Active, QPalette::Inactive, QPalette::Disabled};
    const QString keys[] = {"active_colors", "inactive_colors", "disabled_colors"};

    for (int group = 0; group < 3; ++group) {
        const QStringList expected = colors.value("ColorScheme/" + keys[group]).toStringList();
        for (const auto role : {QPalette::Window, QPalette::Base, QPalette::Highlight, QPalette::WindowText}) {
            if (expected.size() <= role || !QColor(expected.at(role)).isValid()) {
                qCritical() << "Missing palette color:" << keys[group] << role;
                return 1;
            }
            if (actual.color(groups[group], role) != QColor(expected.at(role))) {
                qCritical() << "Palette mismatch:" << keys[group] << role
                            << actual.color(groups[group], role) << "expected" << expected.at(role);
                return 1;
            }
        }
    }

    qInfo() << qtct << style->objectName()
            << "window:" << actual.color(QPalette::Window).name()
            << "highlight:" << actual.color(QPalette::Highlight).name();
}
