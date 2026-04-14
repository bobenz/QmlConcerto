#ifndef PHRASE_H
#define PHRASE_H

#include <QObject>

class Phrase : public QObject
{
    Q_OBJECT
public:
    explicit Phrase(QObject *parent = nullptr);

signals:
};

#endif // PHRASE_H
