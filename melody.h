#ifndef MELODY_H
#define MELODY_H

#include <QObject>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include "phrase.h"

class Melody : public Phrase, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)

    // The generic list of components
    Q_PROPERTY(QQmlListProperty<Phrase> phrases READ phrases)
    Q_CLASSINFO("DefaultProperty", "phrases")

public:
    explicit Melody(QObject *parent = nullptr);

    // QQmlParserStatus interface
    void classBegin() override;
    void componentComplete() override;

    // Phrase access
    QQmlListProperty<Phrase> phrases();
    QList<Phrase*> phraseList() const;

protected:
    // We leave _play() pure virtual or empty so derived classes
    // (Sequence/Chord) can implement their own execution logic.
    virtual bool _play() override = 0;

    QList<Phrase *> m_phrases;

private:
    // QQmlListProperty callbacks
    static void append(QQmlListProperty<Phrase> *list, Phrase *phrase);
    static int  count (QQmlListProperty<Phrase> *list);
    static Phrase* at (QQmlListProperty<Phrase> *list, int index);
    static void clear (QQmlListProperty<Phrase> *list);
};

#endif // MELODY_H
