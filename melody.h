#ifndef MELODY_H
#define MELODY_H

#include <QJSValue>
#include <QObject>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include "phrase.h"

class QMLCONCERTO_EXPORT Melody : public Phrase, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)

    Q_PROPERTY(QQmlListProperty<Phrase> phrases READ phrases NOTIFY phrasesChanged)
    Q_CLASSINFO("DefaultProperty", "phrases")

    Q_PROPERTY(QJSValue activePolicies
               READ  activePolicies
               WRITE setActivePolicies
               NOTIFY activePoliciesChanged)

public:
    explicit Melody(QObject *parent = nullptr);

    // QQmlParserStatus interface
    void classBegin() override;
    void componentComplete() override;

    QQmlListProperty<Phrase> phrases();
    QList<Phrase*> phraseList() const;

    QJSValue activePolicies() const;
    void     setActivePolicies(const QJSValue &val);
    Q_INVOKABLE void runPolicies();

signals:
    void phrasesChanged();
    void activePoliciesChanged();

protected:
    bool _play()  override;
    bool _reset() override;

    QList<Phrase *> m_phrases;

private:
    QJSValue m_activePolicies;
    // QQmlListProperty callbacks
    static void    append(QQmlListProperty<Phrase> *list, Phrase *phrase);
    static int     count (QQmlListProperty<Phrase> *list);
    static Phrase* at    (QQmlListProperty<Phrase> *list, int index);
    static void    clear (QQmlListProperty<Phrase> *list);
};

#endif // MELODY_H
